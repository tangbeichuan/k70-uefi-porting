#!/bin/bash
set -e
D=/mnt/d/本地项目-01/_tools
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi
mkdir -p /tmp/pmic
if [ ! -f /tmp/pmic/pmic.asm ]; then llvm-objdump -d "$EFI" > /tmp/pmic/pmic.asm; fi
OUT=/tmp/pmic/ranges.txt
: > "$OUT"
for r in "240f0 24150" "95e0 9730" "1f130 1f220" "1ed00 1ee00" "151a0 15230" "1e7b0 1e8b0"; do
  set -- $r
  echo "===== $1 - $2" >> "$OUT"
  python3 $D/pmic_an.py show $1 $2 >> "$OUT"
done
cat "$OUT"
