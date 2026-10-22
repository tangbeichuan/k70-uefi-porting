#!/usr/bin/env bash
# k163_dis2.sh -- key symbols in keys163 Menu (CpuDeadLoop / Blt / event ring).
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
echo "Menu EFI: $E"
llvm-objdump -d "$E" > /tmp/m163b.asm
echo "--- CpuDeadLoop symbol refs ---"
grep -n "CpuDeadLoop" /tmp/m163b.asm || echo "  (no symbol annotation)"
echo "--- last 60 lines of .text disassembly (tail loop / halt) ---"
tail -60 /tmp/m163b.asm
echo "--- blr sites 0x24..0x2a with 2 preceding lines ---"
awk '/^ *2[4-9][0-9a-f][0-9a-f]:/ {buf[NR]=$0} END{}' /tmp/m163b.asm >/dev/null || true
grep -nE "^ *2[4-9][0-9a-f]{2}:.*(blr|br) " /tmp/m163b.asm | head -30
