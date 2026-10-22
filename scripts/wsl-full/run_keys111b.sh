#!/usr/bin/env bash
set -e -o pipefail
TAG=keys111
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
cd /mnt/d/本地项目-01/_k70port_extract/wsl
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys111.sh "$TAG"
python3 - <<'PY'
import pathlib
m = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV')
sfb = bytes.fromhex('6D1EFDDC8D78FC4F1B8ECA2F75651A92')
for name in ('FVMAIN.Fv','SILICIUM_UEFI.fd'):
    b=(m/name).read_bytes(); print(f"{name}: size={len(b)} simplefb={b.count(sfb)}")
PY
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd"
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG"