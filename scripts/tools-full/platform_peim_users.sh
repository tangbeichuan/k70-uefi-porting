#!/bin/bash
U=/root/k70/uefi
echo "=== who calls PlatformPeim / links PlatformPeiLib ==="
grep -rn "PlatformPeim\|PlatformPeiLib" $U/Silicon $U/Platforms $U/Mu_Basecore --include=*.c --include=*.inf --include=*.dsc 2>/dev/null | grep -v Build/ | head -20
echo
echo "=== is our PEI including that module? (FDF PEI area) ==="
sed -n '21,60p' $U/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
