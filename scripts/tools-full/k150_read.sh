#!/bin/bash
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== anchors ==="
grep -n 'Usb149\|MENU149\|CpuDeadLoop\|STATIC VOID\|UnicodeSPrint\|Say (' "$F" | head -40
echo "=== Usb149LateDiag block ==="
L=$(grep -n 'Usb149LateDiag (' "$F" | head -1 | cut -d: -f1)
echo "start line=$L"
sed -n "$((L-3)),$((L+95))p" "$F"
echo "=== call site ==="
grep -n -A6 'MENU149' "$F"
