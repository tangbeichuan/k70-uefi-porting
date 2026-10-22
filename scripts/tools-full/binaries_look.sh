#!/bin/bash
U=/root/k70/uefi
echo "=== Binaries/vermeer tree (depth 3) ==="
find $U/Binaries/vermeer -maxdepth 3 -type d | head -40
echo
echo "=== any header in Binaries mentioning Dtb ==="
grep -rli "dtbextn\|DtbExtn" $U/Binaries 2>/dev/null | head -20
echo
echo "=== all vendor driver dirs ==="
ls $U/Binaries/vermeer/QcomPkg/Drivers | tr '\n' ' '
echo
echo "=== fv_dump location ==="
find /mnt/d/本地项目-01 -maxdepth 4 -type d -name 'fv_dump' 2>/dev/null | head
