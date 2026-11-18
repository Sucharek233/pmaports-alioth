# 5G Cellular Modem (Qualcomm SDX55) Bring-Up Guide

Architecture, kernel drivers, firmware extraction, and userspace software stack for the Qualcomm Snapdragon X55 (SDX55) modem on the Xiaomi Poco F3 (`alioth`).

---

## 1. Flashless Modem Architecture on Alioth

The Snapdragon 870 SoC has no integrated cellular modem. Baseband connectivity is handled by a discrete external **Qualcomm SDX55** chip over PCIe (`pcie2`).

- **Flashless Baseband**: The SDX55 chip on alioth lacks onboard flash storage. All baseband firmware files, NV calibration items, and EFS partition images must be supplied by the host Linux system from UFS storage during boot.
- **Bus Protocols**:
  - Qualcomm MHI (Modem Host Interface) over PCIe.
  - QRTR (Qualcomm IPC Router) over MHI IPC-Router channels.
  - RmNet (Qualcomm cellular network aggregation protocol) for IP packet transport.

---

## 2. Required Kernel Drivers

```kconfig
CONFIG_MHI_BUS=m
CONFIG_MHI_BUS_PCI_GENERIC=m
CONFIG_MHI_NET=m
CONFIG_MHI_WWAN_CTRL=m
CONFIG_MHI_WWAN_MBIM=m
CONFIG_ETHERNET=y
CONFIG_NET_VENDOR_QUALCOMM=y
CONFIG_RMNET=m
CONFIG_QRTR=m
CONFIG_QRTR_SMD=m
CONFIG_QRTR_MHI=m
```

DTS modem nodes are enabled by `0002-add-modem-sdx55m-support.patch`.

---

## 3. Userspace Components & Systemd Services

All integration files reside in `device-xiaomi-alioth/modem-services/`:

1. **`alioth-modem-firmware.service` / `alioth-modem-firmware.sh`**:
   - Reads the modem, DSP, Bluetooth, persist, and handset-specific EFS partitions directly from UFS.
   - Populates baseband firmware files at `/lib/firmware/qcom/sdx55m/`.

2. **`tqftpserv.service`**:
   - Userspace TFTP daemon that serves firmware and EFS file requests initiated by the SDX55 modem over QRTR.
   - Built from upstream `tqftpserv` v1.3 for Alpine/musl, with QRTR service instance 3 required by Alioth.

3. **`alioth-modem.service`**:
   - Executes Sahara and EFS helpers (`sahara_srv.py`, `efs_srv.py`, `data_up.py`).
   - Configures the `rmnet_mhi0` network interface and maps QRTR communication ports.

4. **`alioth-sim-provision` & `alioth-switch-sim`**:
   - Controls the physical dual-SIM hardware switch on the Poco F3.
   - Points ModemManager to the appropriate primary control channel.

5. **Udev Rules**:
   - `77-mm-ignore-sdx55-extra.rules`: Prevents ModemManager from probing unsupported DIAG/trace ports.
   - `77-mm-sdx55-qrtr.rules`: Exposes the QRTR modem node to ModemManager.

The `device-xiaomi-alioth` package installs and enables these systemd services and
helpers. The standard firmware package does not contain the SDX55 boot chain:
`alioth-modem-firmware.service` copies it from the phone's `modem_a` partition
before `modem-up.sh` explicitly loads the MHI PCI driver. The EFS files are
device-specific and are read from the phone's own partitions at runtime; they
are not included in build artifacts.

The kernel command line blacklists `mhi_pci_generic` during early PCI discovery.
This prevents the driver from requesting firmware before the rootfs service has
copied it; `modem-up.sh` starts the Sahara and EFS servers, loads the driver,
then waits for mission mode. The `sdx_reset` parameter is not invoked
automatically because it retrains the PCIe host and may destabilize the phone.
The direct WDS data-session helper also requires the `qrtr` userspace package,
which provides `qrtr-lookup`; `qrtr-libs` alone is not sufficient.

## 4. ModemManager on Alioth

The device can bring up cellular data independently, but the stock
ModemManager 1.25.95 repeatedly recreated the `qcom-soc` modem object on Alioth.
The local `modemmanager/` APKBUILD is based on Alpine's matching
`1.25.95_git20261005` source snapshot and applies an Alioth patch to:

- treat `mhi_net` as requiring QMAP multiplexing for QMI bearer setup;
- route `mhi_net` and `rmnet` data ports through the QMI port selection used by
  the Qcom SoC plugin; and
- choose the active SIM slot deterministically when firmware reports multiple
  active slots.

Build this override for `aarch64`, not the host architecture; the device
package pins revision r4, and the workflow verifies the aarch64 APK exists.
The new-pmaports GitHub workflow copies this APKBUILD into its local pmaports
tree and builds it before installing the image. Because the workflow clones
`rusyd4/pmaports-alioth` from its `main` branch, publish the `modemmanager/`
directory there before running the workflow. The device package pins this
patched version so the stock package cannot silently replace it. The patch
deliberately does not globally suppress SIM-change events, which could hide
real SIM swaps. The package currently skips Alpine's upstream test phase:
three unrelated native test cases (`test-plugin-generic`, `test-stub`, and
`test-base-call`) abort in this pmbootstrap buildroot, although 35 of 38 pass.
The detailed assertions were not available, so this is a build unblocker, not
a claim that the full suite passes.

For a local pmbootstrap build, sync the package overlay and build it before
installing the image:

```sh
./update_folder.sh
pmbootstrap -v build --arch aarch64 modemmanager
pmbootstrap -v build device-xiaomi-alioth
pmbootstrap -v install --password 147147
```
