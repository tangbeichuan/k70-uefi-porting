#!/usr/bin/env python3
"""pmic_14_dtb.py -- list every DTBExtn call in PmicDxeLa and its argument strings.

DTBExtn thunks live at 0x95f8..0x9728; 0x2410c..0x24138 are one-line tail
trampolines (b <thunk>) used by the rest of the module.
"""
import re, sys

ASM = '/tmp/pmic/pmic.asm'
EFI = '/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi'

SLOTS = {
    0x2410c: 0x28, 0x24110: 0x30, 0x24118: 0x68, 0x2411c: 0x70,
    0x24120: 0x88, 0x24124: 0x90, 0x24128: 0x98, 0x2412c: 0xa0,
    0x24130: 0xa8, 0x24134: 0xc8, 0x24138: 0xe0,
}

lines = open(ASM, encoding='utf-8', errors='replace').read().splitlines()
insns = []
for ln in lines:
    m = re.match(r'\s*([0-9a-f]{4,8}):\s+([0-9a-f]{8})\s+(.*)', ln)
    if m:
        insns.append((int(m.group(1), 16), m.group(3).strip()))
addr2idx = {a: i for i, (a, t) in enumerate(insns)}

efi = open(EFI, 'rb').read()

def cstr(off, maxlen=160):
    end = off
    while end < len(efi) and end - off < maxlen and 32 <= efi[end] < 127:
        end += 1
    if end == off:
        return None
    return efi[off:end].decode('ascii', 'replace')

def resolve_imm(txt):
    """adrp xN, 0xYY000  -> page;  add xN, xN, #imm -> full"""
    m = re.match(r'adrp\s+(x\d+),\s*(0x[0-9a-f]+)', txt)
    if m:
        return m.group(1), int(m.group(2), 16)
    return None, None

def reg_of(txt, op='add'):
    m = re.match(op + r'\s+(x\d+),\s*(x\d+),\s*#(0x[0-9a-f]+|\d+)', txt)
    if m:
        return m.group(1), m.group(2), int(m.group(3), 16)
    return None, None, None

def ldr_imm(txt):
    m = re.match(r'ldr\s+(x\d+),\s*\[(x\d+),\s*#(0x[0-9a-f]+|\d+)\]', txt)
    if m:
        return m.group(1), m.group(2), int(m.group(3), 16)
    return None, None, None

def window(i, n=60):
    """walk back to previous call/branch-out or n insns"""
    out = []
    j = i - 1
    while j >= 0 and len(out) < n:
        a, t = insns[j]
        if re.match(r'(ret|blr)', t) or re.match(r'b\s+0x', t) or re.match(r'b\.\w+\s+0x', t):
            break
        out.append((a, t))
        j -= 1
    out.reverse()
    return out

results = []
for i, (a, t) in enumerate(insns):
    m = re.match(r'bl\s+(0x[0-9a-f]+)', t)
    if not m:
        continue
    tgt = int(m.group(1), 16)
    if tgt not in SLOTS:
        continue
    win = window(i)
    # register value tracking, simple: page regs then add
    reg = {}
    strargs = []
    for wa, wt in win:
        r, page = resolve_imm(wt)
        if r:
            reg[r] = page
            continue
        d, s, imm = reg_of(wt)
        if d:
            if s in reg and isinstance(reg[s], int):
                reg[d] = reg[s] + imm
            continue
        d, s, imm = ldr_imm(wt)
        if d and s in reg and isinstance(reg[s], int):
            v = reg[s] + imm
            # read qword from image data
            if 0x2f000 <= v < 0x39000:
                q = int.from_bytes(efi[v:v+8], 'little')
                reg[d] = ('mem', q)
            else:
                reg[d] = ('mem', v)
            continue
    args = []
    for rn in ('x0', 'x1', 'x2', 'x3'):
        v = reg.get(rn)
        if isinstance(v, int) and 0x20000 <= v < 0x39000:
            s = cstr(v)
            if s:
                args.append('%s=%r' % (rn, s))
            else:
                args.append('%s=0x%x' % (rn, v))
        elif isinstance(v, tuple):
            q = v[1]
            if 0x20000 <= q < 0x39000:
                s = cstr(q)
                args.append('%s=[0x%x]%s' % (rn, q, ('->%r' % s) if s else ''))
            else:
                args.append('%s=[0x%x]' % (rn, q))
        elif isinstance(v, int):
            args.append('%s=0x%x' % (rn, v))
    results.append((a, tgt, SLOTS[tgt], ' '.join(args)))

print('sites: %d' % len(results))
for a, tgt, slot, args in results:
    print('0x%06x  +0x%02x  %s' % (a, slot, args))
