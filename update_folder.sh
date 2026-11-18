#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PMAPORTS="$HOME/.local/var/pmbootstrap/cache_git/pmaports/device/testing"

mkdir -p "$PMAPORTS"

set -- \
	linux-postmarketos-qcom-sm8250-alioth \
	device-xiaomi-alioth \
	firmware-xiaomi-alioth \
	modemmanager

for package do
	if [ ! -d "$SCRIPT_DIR/$package" ]; then
		echo "Package directory not found: $SCRIPT_DIR/$package" >&2
		exit 1
	fi
done

for package do
	rm -rf -- "$PMAPORTS/$package"
	cp -a "$SCRIPT_DIR/$package" "$PMAPORTS/$package"
done

echo "Updated pmbootstrap package cache"
