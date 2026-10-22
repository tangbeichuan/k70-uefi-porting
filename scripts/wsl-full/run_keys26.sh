#!/bin/bash
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "===== BUILD keys26 ====="
bash build_keys25.sh keys26 2>&1 | tail -12
echo "===== PACK keys26 ====="
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys26.fd keys26 2>&1 | tail -8
echo "===== ARTIFACTS ====="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys26*.img 2>/dev/null
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys26*.img 2>/dev/null
