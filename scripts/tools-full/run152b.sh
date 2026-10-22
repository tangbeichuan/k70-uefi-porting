#!/bin/bash
# run152b.sh -- rebuild keys152 after restoring the MemoryMapLib "USB" row.
# The previous restore used copy2 (mtime preserved) so make considered Sec.efi
# up-to-date and kept the "row removed" PEI.  touch the source first.
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys152
python3 /mnt/d/本地项目-01/_tools/k152_restore_mm.py
touch /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
ls -l --time-style=full-iso /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c

# regenerate build scripts from keys151 lineage (same as run152.sh)
sed 's/keys151/keys152/g' build_keys151.sh > build_keys152.sh
sed 's/keys151/keys152/g' run_keys151.sh > run_keys152.sh
# insert the keys152 menu patch right after patch_menu101.py
if ! grep -q patch_usb152 build_keys152.sh; then
  sed -i 's#\(patch_menu101\.py\)#\1 \&\& python3 /mnt/d/本地项目-01/_tools/patch_usb152.py#' build_keys152.sh
fi
# Menu check must look at UTF-16 strings
if grep -q 'BlockIO devices' run_keys152.sh; then
  sed -i 's#strings "\$MENUD" | grep -q "BlockIO devices"#strings -el "$MENUD" | grep -q "MENU152"#' run_keys152.sh
fi
grep -n 'patch_usb152\|MENU152' build_keys152.sh run_keys152.sh || true

bash run_keys152.sh
echo "=== BUILD DONE rc=$? ==="
FD=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI-keys152.fd
ls -l "$FD"
sha256sum "$FD"
cp -f "$FD" /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152.fd
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152.fd keys152
IMG=/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys152.img
cd /mnt/d/本地项目-01/K70-UEFI-build || exit 1
cp -f Mu-vermeer-keys152.img Mu-vermeer-keys152-fat.img
cp -f Mu-vermeer-keys152.img K70-keys152-MINIMAL-MENU.img
ls -l Mu-vermeer-keys152.img K70-keys152-MINIMAL-MENU.img
sha256sum Mu-vermeer-keys152.img K70-keys152-MINIMAL-MENU.img
cp -f /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref /mnt/d/本地项目-01/_tools/guid-keys152.xref
echo "=== ALL DONE ==="
