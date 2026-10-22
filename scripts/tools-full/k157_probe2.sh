#!/usr/bin/env bash
set -e
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "--- occurrences of 0x0010F / CpuDeadLoop / Usb150 ---"
grep -nE '0x0010F0|CpuDeadLoop|Usb150' "$M" || true
echo "--- current MENU157? ---"
grep -nE 'MENU157|USB157' "$M" || true
echo "--- entry tail ---"
sed -n '995,1060p' "$M" 2>/dev/null || tail -60 "$M"
