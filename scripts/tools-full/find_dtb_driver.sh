#!/bin/bash
U=/root/k70/uefi
echo "=== QcomPkg/Drivers ==="
ls $U/Silicon/Qualcomm/QcomPkg/Drivers 2>/dev/null | tr '\n' ' '
echo; echo
echo "=== SiliciumPkg/Drivers ==="
find $U -maxdepth 4 -type d -name SiliciumPkg 2>/dev/null | head
ls $U/SiliciumPkg/Drivers 2>/dev/null | tr '\n' ' '
echo; echo
echo "=== any dir with dt/fdt in name (whole tree, excluding Build) ==="
find $U -type d \( -iname '*fdt*' -o -iname '*dtb*' -o -iname '*devicetree*' \) 2>/dev/null | grep -v '/Build/' | head -20
echo
echo "=== grep for LocateProtocol + DtbExtn style in Silicon ==="
grep -rn "DtbExtn\|DTBExtn\|3A06E1E8" $U/Silicon $U/Platforms 2>/dev/null | grep -v Build/ | head -10
