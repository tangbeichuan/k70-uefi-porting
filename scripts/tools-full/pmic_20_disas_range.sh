#!/bin/bash
# disassemble a given efi and dump an address range
set -e
EFI="$1"
LO="$2"
HI="$3"
OUT=/tmp/dump_$(basename "$EFI" .efi).asm
if [ ! -f "$OUT" ]; then
  llvm-objdump -d "$EFI" > "$OUT"
fi
python3 - "$OUT" "$LO" "$HI" <<'EOF'
import re, sys
asm, lo, hi = sys.argv[1], int(sys.argv[2],16), int(sys.argv[3],16)
for ln in open(asm, encoding='utf-8', errors='replace'):
    m = re.match(r'\s*([0-9a-f]{4,8}):\s+([0-9a-f]{8})\s+(.*)', ln)
    if m:
        a = int(m.group(1),16)
        if lo <= a < hi:
            print('%08x: %s' % (a, m.group(3).strip()))
EOF
