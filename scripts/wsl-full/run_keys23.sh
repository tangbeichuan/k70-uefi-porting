#!/bin/bash
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "===== BUILD keys23 ====="
bash build_keys23.sh keys23 2>&1 | tail -30
echo "===== PACK keys23 ====="
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys23.fd keys23 2>&1 | tail -20
echo "===== ARTIFACTS ====="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys23*.img 2>/dev/null
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys23*.img 2>/dev/null
