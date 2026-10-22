#!/bin/bash
W=/mnt/d/本地项目-01/_k70port_extract/wsl
echo "===== wsl dir ====="
ls -lt $W | head -25
echo "===== build_keys151.sh patch chain ====="
grep -n "patch_\|pack_keys\|build_uefi" $W/build_keys151.sh | head -40
echo "===== run_keys151.sh ====="
cat $W/run_keys151.sh
echo "===== pack_keys.sh ====="
[ -f $W/pack_keys.sh ] && cat $W/pack_keys.sh | head -60
echo "===== menu patch scripts in _tools ====="
ls -lt /mnt/d/本地项目-01/_tools/patch_*menu* /mnt/d/本地项目-01/_tools/*Menu* 2>/dev/null | head
echo "===== Menu sources ====="
ls -l /mnt/d/本地项目-01/_tools/VermeerMenuDxe.c /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c 2>/dev/null
sha256sum /mnt/d/本地项目-01/_tools/VermeerMenuDxe.c /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c 2>/dev/null
