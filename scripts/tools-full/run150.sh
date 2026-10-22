#!/bin/bash
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys149/keys150/g' build_keys149.sh > build_keys150.sh
sed 's/keys149/keys150/g' run_keys149.sh > run_keys150.sh
chmod +x build_keys150.sh run_keys150.sh
echo "=== RunMenu refs (unused-static check) ==="
grep -n 'RunMenu' /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== apply patch_usb150 ==="
python3 /mnt/d/本地项目-01/_tools/patch_usb150.py
echo "=== build ==="
set +e
bash run_keys150.sh 2>&1 | tail -12
echo "=== menu efi strings ==="
M=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
echo "menu efi: $M"
strings "$M" | grep -c 'USB150'
strings "$M" | grep 'USB150' | head -6
echo "=== artifacts ==="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys150.img 2>/dev/null
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys150.fd \
          /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys150.img 2>/dev/null
