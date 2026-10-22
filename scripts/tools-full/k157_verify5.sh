#!/usr/bin/env bash
set -e
D=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name VermeerDtbExtnDxe.efi | head -1)
echo "dtbextn: $D ($(stat -c%s "$D") B)"
llvm-objdump -d "$D" > /tmp/dtb157.asm
echo "=== DWC3 early bring-up: 0xC704 / 0xC200 / 0xC70C references ==="
grep -nE '#0xc704|#0xc200|#0xc70c|#0xc110|#0xc708' /tmp/dtb157.asm | head -30
echo "=== context around the DCTL store (0xc704) ==="
grep -n '#0xc704' /tmp/dtb157.asm | head -4 | while read -r L; do
  n=${L%%:*}
  sed -n "$((n-6)),$((n+6))p" /tmp/dtb157.asm
  echo "  ----"
done
