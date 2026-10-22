#!/bin/bash
U=/root/k70/uefi
echo "=== XblProtocols.c GetXblHobAddresses ==="
sed -n '95,175p' $U/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/XblProtocols.c
echo
echo "=== PcdPlatformType set anywhere for vermeer/kailua ==="
grep -rn "PcdPlatformType" $U/Platforms/Xiaomi/vermeerPkg $U/Platforms/Xiaomi/KailuaPkg $U/Silicon/Qualcomm/QcomPkg/*.dec $U/Silicon/Qualcomm/QcomPkg/*.dsc.inc 2>/dev/null | head
echo
echo "=== vermeer.dsc LibraryClasses sections? ==="
grep -n '^\[LibraryClasses' $U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
grep -n '^\[Packages' $U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo
echo "=== KailuaPkg.dsc.inc includes ==="
grep -n 'include\|PlatformPeiLib\|LibraryClasses' $U/Platforms/Xiaomi/KailuaPkg/KailuaPkg.dsc.inc | head -20
