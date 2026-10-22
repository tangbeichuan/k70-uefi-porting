#!/bin/bash
set -u
TO=/mnt/d/本地项目-01/_tools
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd
E=/tmp/ucfg145.efi
[ -s "$E" ] || python3 $TO/cf146e.py "$FD" "$E" >/dev/null
[ -s /tmp/u145.asm ] || llvm-objdump -d "$E" > /tmp/u145.asm
echo "=== absolute addr refs ==="
grep -n -E "0x12c20|0x12c6b|0x12c33" /tmp/u145.asm | head -20
echo "=== adrp 0x12000 site count ==="
grep -c "adrp.*0x12000" /tmp/u145.asm || true
echo "=== add #0xc20/#0xc6b/#0xc33 ==="
grep -n -E "add\s+x[0-9]+, x[0-9]+, #0xc(20|6b|33)\s*$" /tmp/u145.asm | head
echo "=== any 'add ... #0xc2' / '#0xc6' ==="
grep -n -E "add\s+x[0-9]+, x[0-9]+, #0xc[0-9a-f]{2}\s*$" /tmp/u145.asm | grep -E "#0xc(2|6|3)" | head -20
echo "=== adrp 0x12000 blocks ==="
grep -n "adrp.*0x12000" /tmp/u145.asm | head -20
