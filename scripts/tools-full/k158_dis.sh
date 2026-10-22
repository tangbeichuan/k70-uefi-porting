#!/usr/bin/env bash
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name VermeerDtbExtnDxe.efi | head -1)
llvm-objdump -d "$E" > /tmp/dtb158.asm
awk '/^[ ]+2[0-9a-f][0-9a-f][0-9a-f]:/ {print}' /tmp/dtb158.asm | awk '{
  a=strtonum("0x"$1); if (a>=0x21f0 && a<=0x2340) print
}' 2>/dev/null || sed -n '/ 21f0:/,/ 2340:/p' /tmp/dtb158.asm
echo "=== raw sed window ==="
sed -n '/^    21f0:/,/^    2340:/p' /tmp/dtb158.asm
