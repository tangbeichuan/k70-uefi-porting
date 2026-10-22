#!/usr/bin/env bash
set -e -o pipefail
TAG=keys108
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
cd /mnt/d/本地项目-01/_k70port_extract/wsl

# force a full FV/FD relink (stale FD was silently reused before)
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
echo "removed stale FV artefacts"

sed 's/keys107/keys108/g' build_keys107.sh > build_keys108.sh
chmod +x build_keys108.sh
bash build_keys108.sh "$TAG"

echo "=== post-build artefacts ==="
ls -l --time-style=+%H:%M:%S "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
grep -i "DCFD1E6D" "$B/FV/Guid.xref" | head -2
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG"