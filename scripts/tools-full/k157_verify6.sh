#!/usr/bin/env bash
set -e
D=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name VermeerDtbExtnDxe.efi | head -1)
llvm-objdump -d "$D" > /tmp/dtb157.asm
echo "=== 0xa60 / 0xa6f references ==="
grep -nE '#0xa60|#0xa6f|movk.*0xa6' /tmp/dtb157.asm | head -30
echo "=== asm 0x2060-0x21c0 ==="
sed -n '/ 2060:/,/ 21c0:/p' /tmp/dtb157.asm
