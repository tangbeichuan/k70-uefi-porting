#!/usr/bin/env bash
set -e -o pipefail
TAG=keys144
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
cd /mnt/d/本地项目-01/_k70port_extract/wsl
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys144.sh "$TAG" 2>&1 | tee /tmp/$TAG-build.log | tail -6
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tee /tmp/$TAG-pack.log | tail -4

########################################################################
# Artifact: the task asks for the FAT build under a "-fat" name.  The 
# container bytes are identical to Mu-vermeer-<tag>.img (the FAT volume
# lives inside the firmware), so just publish a copy under both names.
########################################################################
OUT=/mnt/d/本地项目-01/K70-UEFI-build
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"
echo "=== $TAG images ==="
sha256sum "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"

########################################################################
# Prove the new driver and the unchanged boot display are in the build.
########################################################################
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
LOGD=$(find "$B" -name 'VermeerLogDiskDxe.efi' | head -1)
MENUD=$(find "$B" -name 'VermeerMenuDxe.efi' | head -1)
echo "--- logdisk EFI: $LOGD ---"
for pat in "volume ready" "FAT16] geometry" "selfcheck" "BOOTLOG" "K70 LOGDISK"; do
    grep -aq "$pat" "$LOGD" && echo "  OK: $pat" || { echo "  MISSING: $pat"; exit 1; }
done
echo "--- menu EFI: $MENUD ---"
grep -aq "BlockIO devices" "$MENUD" && echo "  OK: [UI] BlockIO devices display" \
    || { echo "  MISSING BlockIO display"; exit 1; }
echo "--- FV module list ---"
grep -i 'VermeerLogDiskDxe' "/tmp/guid-$TAG.xref" || { echo "LOGDISK NOT IN FV"; exit 1; }
echo "--- build log tail ---"
tail -12 "/tmp/$TAG-build.log"
