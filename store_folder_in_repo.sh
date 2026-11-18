#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PMAPORTS="$HOME/.local/var/pmbootstrap/cache_git/pmaports/device/testing"

set -- \
	linux-postmarketos-qcom-sm8250-alioth \
	device-xiaomi-alioth \
	firmware-xiaomi-alioth \
	modemmanager

for package do
	if [ ! -d "$PMAPORTS/$package" ]; then
		echo "Package directory not found in pmbootstrap cache: $PMAPORTS/$package" >&2
		exit 1
	fi
done

for package do
	rm -rf -- "$SCRIPT_DIR/$package"
	cp -a "$PMAPORTS/$package" "$SCRIPT_DIR/$package"
done

echo "Updated repository package directories"
