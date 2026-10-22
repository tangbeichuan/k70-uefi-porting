#!/usr/bin/env bash
set -e
M=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name VermeerMenuDxe.efi | head -1)
echo "menu: $M"
python3 - "$M" <<'PY'
import sys, pathlib, re
raw = pathlib.Path(sys.argv[1]).read_bytes()
# all UTF-16LE strings >=6 chars containing 157 / MENU
s = raw.decode('utf-16-le', errors='ignore')
for m in re.finditer(r'[ -~]{6,}', s):
    t = m.group(0)
    if '157' in t or 'MENU' in t or 'resident' in t or 'alive' in t:
        print(" utf16:", repr(t[:110]))
PY
llvm-objdump -d "$M" > /tmp/menu157.asm
echo "=== disasm: Stall / ReadKeyStroke / Say calls ==="
grep -nE '#0x86a0|#0x186a0|#0x1,$|bl.*<Say|ldr.*#0xf8\]' /tmp/menu157.asm | head -20
echo "=== entry region: last 60 instrs ==="
tail -90 /tmp/menu157.asm
