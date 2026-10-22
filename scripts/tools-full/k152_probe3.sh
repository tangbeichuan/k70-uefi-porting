#!/bin/bash
T=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "lines=$(wc -l < $T)"
grep -n "^[A-Za-z_].*(\|^STATIC\|^EFI_STATUS\|^VOID\|^UINTN\|\[USB150\]\|\[USB149\]\|CpuDeadLoop\|LoadImage\|StartImage\|SimpleFb\|\[MENU150\]\|RunMenu\|gST->ConOut\|Say" $T | head -80
