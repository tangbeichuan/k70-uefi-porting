#!/bin/bash
U=/root/k70/uefi
echo "=== DtPlatformDtbLoaderLib implementations in tree ==="
find $U -type d -iname 'DtPlatformDtbLoaderLib*' 2>/dev/null
echo
echo "=== who defines DtPlatformDtbLoaderLib in DSC/INC (vermeer) ==="
grep -rn "DtPlatformDtbLoaderLib" $U/Platforms/Xiaomi/vermeerPkg $U/Mu_Basecore 2>/dev/null | grep -v Binary | head -20
echo
echo "=== line 82 context of any *ServicesLib.c used by drivers ==="
for f in $(find $U/Mu_Basecore -name '*ServicesLib.c' | head -20); do
  n=$(sed -n '80,84p' "$f" | grep -c "ASSERT_EFI_ERROR")
  if [ "$n" != "0" ]; then echo "HIT: $f"; sed -n '70,90p' "$f"; fi
done
echo
echo "=== Fdt variant source ==="
ls $U/Mu_Basecore/EmbeddedPkg/Library/DtPlatformDtbLoaderLib*/ 2>/dev/null
for f in $U/Mu_Basecore/EmbeddedPkg/Library/DtPlatformDtbLoaderLib*/*.c; do echo "----- $f"; head -80 "$f"; done
