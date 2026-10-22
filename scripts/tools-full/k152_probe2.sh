#!/bin/bash
T=/mnt/d/本地项目-01/_tools
echo "===== patch_menu101.py ====="; head -40 $T/patch_menu101.py
echo "===== patch_usb150.py (head 80) ====="; head -80 $T/patch_usb150.py
echo "===== menu sources sizes ====="
ls -l $T/VermeerMenuDxe.c /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c 2>/dev/null
echo "===== usb150 markers in _tools copy ====="
grep -n "Usb150\|USB150\|MENU150\|CpuDeadLoop\|LoadImage\|StartImage\|Say(" $T/VermeerMenuDxe.c | head -60
