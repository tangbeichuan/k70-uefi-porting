#!/usr/bin/env bash
# k163_vendor.sh -- prove the vendor UsbfnDwc3Dxe event-ring write ORDER
# (GEVNTADRLO/HI -> GEVNTSIZ -> GEVNTCOUNT -> DEVTEN) for the keys163 report.
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
# locate every store to the event/deven window: 0xc400,0xc404,0xc408,0xc40c,0xc708
want = {0xc400: 'GEVNTADRLO', 0xc404: 'GEVNTADRHI', 0xc408: 'GEVNTSIZ', 0xc40c: 'GEVNTCOUNT', 0xc708: 'DEVTEN'}
hits = []
for a, ln in rows:
    for off, name in want.items():
        if f'0xc{off - 0xc000:x}' in ln or f'#0x{off:x}' in ln:
            hits.append((a, name, ln.strip()))
# print a 0x60-line window around the first '0xc40' hit
anchors = [a for a, n, l in hits if n.startswith('GEVNT')]
if anchors:
    lo = min(anchors) - 0x40
    hi = max(anchors) + 0x60
    print(f"--- UsbfnDwc3Dxe event-ring window 0x{lo:x}..0x{hi:x} ---")
    for a, ln in rows:
        if lo <= a < hi:
            print(ln)
print("--- summary of register constants seen in that window ---")
for a, n, l in hits:
    if anchors and min(anchors) - 0x40 <= a < max(anchors) + 0x60:
        print(f"  0x{a:x} {n}: {l}")
PY
