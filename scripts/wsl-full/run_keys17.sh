#!/bin/bash
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "===== BUILD keys17 ====="
bash build_keys17.sh keys17 2>&1 | tail -30
echo "===== PACK keys17 ====="
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys17.fd
bash pack_keys.sh keys17 2>&1 | tail -30
echo "===== ARTIFACTS ====="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys17*.img 2>/dev/null
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys17*.img 2>/dev/null
