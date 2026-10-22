#!/usr/bin/env python3
import re, sys
ASM = "/tmp/pmic/pmic.asm"
lines = open(ASM, encoding="utf-8", errors="replace").read().splitlines()
pat = re.compile(r'^\s*([0-9a-f]+):\s*(?:[0-9a-f]{8}\s+)?(.*)$')
insns = []
for ln in lines:
    m = pat.match(ln)
    if m:
        text = m.group(2).strip()
        # drop objdump symbol annotations
        text = re.sub(r'\s*<[^>]*>', '', text)
        text = re.sub(r'\s*//.*$', '', text)
        insns.append((int(m.group(1),16), text.lower()))

TARGET_GLOBALS = {0x353a8: "DTBExtn", 0x353c0: "IFC2raw", 0x353c8: "IFC2", 0x353b8: "IFC2x", 0x36750: "IFC3"}
cur = {}
results = []
blr_sites = []
for a, t in insns:
    toks = t.split(None, 1)
    if not toks: continue
    mn = toks[0]; ops = toks[1] if len(toks)>1 else ''
    if mn == 'ret':
        cur.clear(); continue
    if mn == 'adrp':
        m = re.match(r'(x\d+), (0x[0-9a-f]+)', ops)
        if m: cur[m.group(1)] = ('abs', int(m.group(2),16))
        continue
    if mn == 'add':
        m = re.match(r'(x\d+), (x\d+), #(0x[0-9a-f]+)$', ops)
        if m:
            rd,rs,imm = m.group(1), m.group(2), int(m.group(3),16)
            if rs in cur and cur[rs][0]=='abs':
                cur[rd]=('abs', cur[rs][1]+imm)
            else:
                cur[rd]=('unk',)
        else:
            m2 = re.match(r'(x\d+), (x\d+), (x\d+)', ops)
            if m2: cur[m2.group(1)]=('unk',)
        continue
    if mn == 'mov':
        m = re.match(r'(x\d+), (x\d+)$', ops)
        if m:
            cur[m.group(1)] = cur.get(m.group(2), ('unk',))
            continue
        m = re.match(r'(x\d+), #', ops)
        if m:
            cur[m.group(1)] = ('unk',)
            continue
        continue
    if mn == 'ldr' and ops.startswith('x'):
        m = re.match(r'(x\d+), \[(x\d+)(?:, #(0x[0-9a-f]+))?\]$', ops)
        if m:
            rd = m.group(1); bs = m.group(2); disp = int(m.group(3),16) if m.group(3) else 0
            if bs in cur and cur[bs][0]=='abs':
                gaddr = cur[bs][1] + disp
                if gaddr in TARGET_GLOBALS:
                    cur[rd] = ('iface', gaddr)
                else:
                    cur[rd] = ('mem', gaddr)
                continue
            if bs in cur and cur[bs][0]=='iface':
                results.append((a, cur[bs][1], disp, rd))
                cur[rd] = ('method', cur[bs][1], disp)
                continue
        cur[rd[0:2] if False else re.match(r'(x\d+)', ops).group(1)] = ('unk',)
        continue
    # track blr/br
    if mn in ('blr','br'):
        m = re.match(r'(x\d+)', ops)
        if m:
            r = m.group(1)
            v = cur.get(r)
            kind = ''
            if v:
                if v[0]=='method': kind=f" method(iface=0x{v[1]:x},slot=+0x{v[2]:x})"
                elif v[0]=='iface': kind=f" iface(0x{v[1]:x})"
                elif v[0]=='abs': kind=f" abs(0x{v[1]:x})"
            blr_sites.append((a, mn, r, kind))
    # invalidate written regs: approximate - for other instrs, everything after dest reg unknown
    m = re.match(r'(x\d+|w\d+)', ops)
    if m and mn not in ('cmp','tst','b','cbz','cbnz','tbz','tbnz','stp','str','stur'):
        r = m.group(1)
        rr = r.replace('w','x',1) if r.startswith('w') else r
        cur[rr] = ('unk',)

print("=== loads of method pointers from tracked globals ===")
for a,g,slot,rd in results:
    print(f"load@{a:06x} iface=0x{g:x} slot=+0x{slot:x} -> {rd}")

print("\n=== blr/br sites with tracked origin ===")
for a,mn,r,kind in blr_sites:
    if kind:
        print(f"{a:06x}: {mn} {r}{kind}")

print("\n=== br sites (all) ===")
for a,t in insns:
    if re.match(r'br\s+x\d+$', t):
        print(f"{a:06x}: {t}")
