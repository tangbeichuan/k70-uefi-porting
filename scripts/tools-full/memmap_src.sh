#!/bin/bash
U=/root/k70/uefi
echo "=== MemoryMapHelperLib implementations ==="
find $U -type d \( -iname 'MemoryMapHelperLib*' -o -iname 'MemoryMapLib*' \) 2>/dev/null | grep -v Build/ | head
echo
echo "=== MemoryMapLib mapping in dsc.inc files ==="
grep -rn "MemoryMapLib|\|MemoryMapHelperLib|" $U/Platforms $U/Silicon --include=*.dsc --include=*.inc 2>/dev/null | head -10
echo
echo "=== search 'FD Reserved' / 'FD_Reserved' in sources ==="
grep -rn "FD Reserved\|FD_Reserved" $U --include=*.c --include=*.h --include=*.dts --include=*.dtsi --include=*.json 2>/dev/null | grep -v Build/ | head -10
echo
echo "=== vermeer memory-map source files ==="
find $U/Platforms/Xiaomi/vermeerPkg -iname '*mem*' -o -iname '*map*' 2>/dev/null | head -20
