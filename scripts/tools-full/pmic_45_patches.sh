#!/usr/bin/env bash
set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe
OUT=/tmp/pmicpatch
mkdir -p $OUT
for t in 0x3fe0:0x4020 0x14730:0x14770; do
  lo=${t%%:*}; hi=${t##*:}
  echo "===== stock $lo .. $hi ====="
  llvm-objdump -d --start-address=$lo --stop-address=$hi "$D/PmicDxeLa.efi" 2>/dev/null | tail -n +7
done
echo "===== bytes at patch sites (stock vs patched) ====="
for R in 0x3ff8 0x4000 0x14740; do
  echo "--- file off $R ---"
  echo -n "stock  : "; od -An -tx1 -j $((R)) -N 16 "$D/PmicDxeLa.efi"
  echo -n "patched: "; od -An -tx1 -j $((R)) -N 16 "$D/PmicDxeLa.patched.efi"
done
echo "===== PATCHES-APPLIED.txt ====="
cat "$D/PATCHES-APPLIED.txt"
