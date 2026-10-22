#!/usr/bin/env bash
set -e -o pipefail
TAG=keys121
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
cd /mnt/d/本地项目-01/_k70port_extract/wsl
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys111.sh "$TAG" 2>&1 | tail -4
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tail -3