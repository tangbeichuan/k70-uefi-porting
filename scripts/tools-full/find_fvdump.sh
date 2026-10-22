#!/bin/bash
echo "=== directories with dumped .efi from stock FV ==="
find /mnt/d/本地项目-01 -maxdepth 5 -type f -name 'ffs*' 2>/dev/null | head -5
find /mnt/d/本地项目-01 -maxdepth 5 -type d \( -name '*fv*' -o -name '*ffs*' \) 2>/dev/null | head -20
echo
echo "=== any module name containing Dtb/Fdt/Extn in dumped modules ==="
find /mnt/d/本地项目-01 -type f \( -iname '*dtb*' -o -iname '*fdt*' -o -iname '*extn*' \) 2>/dev/null | grep -v 'Binaries\|_tools\|Build/' | head -20
