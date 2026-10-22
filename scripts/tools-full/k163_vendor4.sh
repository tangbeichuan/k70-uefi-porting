#!/usr/bin/env bash
# k163_vendor4.sh -- vendor UsbfnDwc3Dxe init snippets: DEVTEN write, PHYCFG, GCTL.
set -e
V=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
llvm-objdump -d "$V" > /tmp/ufn163c.asm
python3 - <<'PY'
import re
rows = []
for ln in open('/tmp/ufn163c.asm', errors='ignore'):
    m = re.match(r"^\s*([0-9a-f]+):", ln)
    if m:
        rows.append((int(m.group(1), 16), ln.rstrip()))
def dump(lo, hi, tag):
    print(f"--- {tag} 0x{lo:x}..0x{hi:x} ---")
    for a, ln in rows:
        if lo <= a < hi:
            print(ln)
dump(0x3bf0, 0x3c40, "DEVTEN write")
dump(0x38e0, 0x3930, "GUSB2PHYCFG")
dump(0x3b18, 0x3b60, "GCTL PRTCAPDIR device")
PY
