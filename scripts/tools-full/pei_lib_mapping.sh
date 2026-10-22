#!/bin/bash
U=/root/k70/uefi
echo "=== any dsc mapping 'PlatformPeiLib|' ==="
grep -rn "PlatformPeiLib|" $U --include=*.dsc --include=*.inc 2>/dev/null | grep -v Build/ | head
echo
echo "=== SiliciumPkg dsc library class section ==="
find $U/Silicon/Silicium -name '*.dsc' | head
echo
echo "=== vermeer.dsc: includes + LibraryClasses head ==="
sed -n '1,60p' $U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo
echo "=== PlatformPeiLibNull.c ==="
cat $U/Silicon/Silicium/SiliciumNullPkg/Library/PlatformPeiLibNull/PlatformPeiNull.c
