#!/usr/bin/env bash
# k163_vendor3.sh -- find DEVTEN (0xC708) writes and DCTL RUN (0xC704) in vendor UsbfnDwc3Dxe.
set -e
V=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
llvm-objdump -d "$V" > /tmp/ufn163b.asm
python3 - <<'PY'
import re
rows = []
for ln in open('/tmp/ufn163b.asm', errors='ignore'):
    m = re.match(r"^\s*([0-9a-f]+):", ln)
    if m:
        rows.append((int(m.group(1), 16), ln.rstrip()))
for a, ln in rows:
    if ('0xc708' in ln) or ('0xc704' in ln) or ('0xc70c' in ln) or ('0xc200' in ln) or ('0xc110' in ln):
        print(f"0x{a:x}: {ln.strip()}")
PY
