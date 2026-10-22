#!/bin/bash
P=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo "=== CreateFvList decl/use ==="
grep -n "CreateFvList" "$P" /root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/*.c /root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/*.h 2>/dev/null
echo
echo "=== first 75 lines of PlatformPei.c ==="
sed -n '1,75p' "$P"
echo
echo "=== which symbol sits near FVMAIN base+0x2B98? (map file) ==="
M=$(ls /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/*.map 2>/dev/null | head -1)
echo "map: $M"
[ -n "$M" ] && grep -n "0x0000000000002b9" "$M" | head -10
