#!/usr/bin/env bash
set -e
M=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name VermeerMenuDxe.efi | head -1)
python3 - "$M" <<'PY'
import sys, pathlib
raw = pathlib.Path(sys.argv[1]).read_bytes()
for s in ("done, returning", "MENU157", "key pressed", "still alive", "RunMenu"):
    print(f"  {s!r}: utf16={raw.count(s.encode('utf-16-le'))} ascii={raw.count(s.encode())}")
PY
llvm-objdump -d "$M" > /tmp/menu157.asm
grep -nE 'adrp.*0x5000|adrp.*0x6000' /tmp/menu157.asm | tail -25
echo "=== addresses 0x1c80-0x1d60 ==="
sed -n '/1c80:/,/1d60:/p' /tmp/menu157.asm | head -70
