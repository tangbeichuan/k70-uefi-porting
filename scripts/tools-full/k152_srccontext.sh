#!/bin/bash
# k152_srccontext.sh -- show context of any potentially "write" tokens left in Menu.
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== Usb152Diag body (grep -n -A26) ==="
grep -n "STATIC VOID[[:space:]]*$" "$M" >/dev/null 2>&1
awk '/Usb152Diag \(VOID\)/,/^}/' "$M" | head -40
echo
echo "=== tokens with context ==="
grep -n -E 'PRTCAPDIR|RUN_STOP|QSCRATCH|ForceLoadSimpleFb|LoadImage|StartImage|MmioWrite|PcdGet|GCTL|DCTL' "$M" | head -40
echo
echo "=== tail entry ==="
grep -n -A4 'MENU152' "$M" | head -20
