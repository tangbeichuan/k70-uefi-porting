#!/usr/bin/env bash
set -u
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerDtDumpDxe.efi
ls -l "$B"
for s in "dtb ext addr audit" "probe@" "late probe" "DTB EXTENSION HOB"; do
    printf '  %-24s -> ' "$s"
    grep -c -a "$s" "$B" 2>/dev/null || echo 0
done
echo "=== pack keys19 ==="
bash /mnt/d/本地项目-01/_k70port_extract/wsl/pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys19.fd keys19 2>&1 | tail -6
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys19*
