#!/bin/bash
T=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== USB150/USB149/menu150 lines ==="
grep -n "USB150\|USB149\|MENU150\|MENU149\|CpuDeadLoop\|Usb150\|Usb149" $T
echo "=== tail 900-1009 ==="
sed -n '900,1009p' $T
