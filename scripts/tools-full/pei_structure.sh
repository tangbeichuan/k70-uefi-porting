#!/bin/bash
U=/root/k70/uefi
echo "=== PlatformPeiLib.inf ==="
cat $U/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPeiLib.inf
echo
echo "=== PlatformPei.c tail (entry) ==="
sed -n '110,175p' $U/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo
echo "=== FDF FV sections ==="
grep -n '^\[' $U/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
echo
echo "=== PEIM entries in vermeer.dsc / DXE.inc ==="
grep -n -i 'peim\|PeiMain\|Pei/' $U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc $U/Platforms/Xiaomi/vermeerPkg/Include/*.inc 2>/dev/null | head -30
