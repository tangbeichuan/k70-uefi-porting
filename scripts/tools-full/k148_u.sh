#!/bin/bash
set -u
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
F=$D/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
llvm-objdump -d "$F" > /tmp/u.asm 2>/dev/null
OUT=/mnt/d/本地项目-01/_tools/k148_u.txt
: > $OUT
for r in "3820 3870" "38e0 3940" "3b20 3bc0" "4c90 4d40" "60c0 60f0" "9100 9180" "a860 a8c0" "3de0 3e40" "3c00 3c30"; do
  set -- $r
  echo "===== RANGE $1-$2 =====" >> $OUT
  awk -v lo="$(printf '0x%s' $1)" -v hi="$(printf '0x%s' $2)" '
    { a=$1; sub(":","",a); v=strtonum("0x" a); if (v>=strtonum(lo) && v<=strtonum(hi)) print }
  ' /tmp/u.asm >> $OUT 2>/dev/null || true
done
echo "lines=$(wc -l < $OUT)"