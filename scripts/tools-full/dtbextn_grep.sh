#!/bin/bash
U=/root/k70/uefi
echo "=== grep DTBExtn / DtbExtn in whole tree (text files) ==="
grep -rIl "DTBExtn\|DtbExtn\|DtbExtension\|DTB_EXTN" $U --include=*.h --include=*.c --include=*.inf --include=*.dec --include=*.dsc --include=*.fdf --include=*.py 2>/dev/null | head -20
echo
echo "=== grep in Mu_Basecore only ==="
grep -rn "DtbExtn\|DTBExtn" $U/Mu_Basecore 2>/dev/null | head -20
echo
echo "=== all vendor efi that mention DTBExtn ==="
for f in $U/Binaries/vermeer/QcomPkg/Drivers/*/*.efi; do
  if strings -n 6 "$f" 2>/dev/null | grep -qi 'dtbextn'; then echo "  $(basename $f)"; fi
done
echo
echo "=== nuwa binaries: same check ==="
for f in $U/Binaries/nuwa/QcomPkg/Drivers/*/*.efi; do
  if strings -n 6 "$f" 2>/dev/null | grep -qi 'dtbextn'; then echo "  $(basename $f)"; fi
done 2>/dev/null
