#!/bin/bash
M=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== markers ==="
grep -n 'MENU150\|CpuDeadLoop\|Usb150LateDiag\|Usb150Rd\|Usb150Dump\|Usb150Wr\|VermeerMenuDxeEntry\|ForceLoadSimpleFb' "$M"
echo "=== lines 930..1010 ==="
sed -n '930,1010p' "$M"
