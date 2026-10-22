#!/usr/bin/env bash
# k163_vendor2.sh -- dump UsbfnDwc3Dxe 0x8b80..0x8c60 (event-ring programming).
set -e
V=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
llvm-objdump -d "$V" > /tmp/ufn163.asm
python3 - <<'PY'
import re
rows = []
for ln in open('/tmp/ufn163.asm', errors='ignore'):
    m = re.match(r"^\s*([0-9a-f]+):", ln)
    if m:
        rows.append((int(m.group(1), 16), ln.rstrip()))
for a, ln in rows:
    if 0x8b80 <= a < 0x8c70:
        print(ln)
PY
