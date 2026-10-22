#!/usr/bin/env bash
set -e
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi
llvm-objdump -d "$E" > /tmp/menu160.asm
python3 - <<'PY'
lines = open('/tmp/menu160.asm').read().splitlines()
want = {0xc408: 'GEVNTSIZ', 0xc400: 'GEVNTADRLO', 0xc40c: 'GEVNTCOUNT', 0xc200: 'GUSB2PHYCFG',
        0xc708: 'DEVTEN', 0xc720: 'DALEPENA', 0xc110: 'GCTL'}
def consts(l):
    # decode movz/movk chains crudely: collect #imm values
    return l
# find sequences building 0x0A60Cxxx via movz wX,#0xCxxx ; movk wX,#0xa60
seqs = []
for i, l in enumerate(lines):
    if ', #0xa60, lsl #16' in l:
        # register name
        import re
        m = re.search(r'movk\s+(w\d+|x\d+),\s*#0xa60', l)
        if not m:
            continue
        reg = m.group(1)
        lo = None
        for j in range(max(0, i-3), i):
            m2 = re.search(rf'mov\s+{reg},\s*#(0x[0-9a-f]+)', lines[j])
            if m2:
                lo = int(m2.group(1), 16)
        if lo is None:
            continue
        total = 0x0A600000 + lo
        seqs.append((i, reg, lo, total, lines[i]))
for i, reg, lo, total, l in seqs:
    tag = None
    for off, name in want.items():
        if total == 0x0A600000 + off:
            tag = name
    ctx = lines[i:i+4]
    print(f"--- {reg} = 0x{total:08x} {('= '+tag) if tag else ''}")
    for c in ctx:
        print("   ", c.strip())
PY
echo
echo "=== GEVNTSIZ store check: look for mov wX,#0x1000 then store near GEVNTSIZ ==="
grep -nE 'mov\s+w[0-9]+, #0x1000' /tmp/menu160.asm | head
echo "=== PHYCFG clear mask constants (0xFEBF7FFF style) ==="
grep -nE '#0xfebf|#0x7fff|#0x40000000' /tmp/menu160.asm | head -20
