#!/usr/bin/env python3
import re, sys
ASM = "/tmp/pmic/pmic.asm"
lines = open(ASM, encoding="utf-8", errors="replace").read().splitlines()
pat = re.compile(r'^\s*([0-9a-f]+):\s*(?:[0-9a-f]{8}\s+)?(.*)$')
insns = []
for ln in lines:
    m = pat.match(ln)
    if m:
        insns.append((int(m.group(1),16), m.group(2).strip().lower()))
by_addr = {a:t for a,t in insns}

def find_global_iface(base_adrp, goff):
    """Find thunks: adrp x8,base ; ... ldr x8,[x8,#goff] ; cbz ; ldr xN,[x8,#slot] ; br xN"""
    res=[]
    for i,(a,t) in enumerate(insns):
        if f"adrp" in t and f"0x{base_adrp:x}" in t and "0x35000" in t:
            pass
    return res

# generic: find any "ldr xN, [xM, #off]" followed within 6 insns by "br xN"
out=[]
for i,(a,t) in enumerate(insns):
    m = re.match(r'ldr\s+(x\d+),\s*\[(x\d+),\s*#(0x[0-9a-f]+)\]', t)
    if not m: continue
    reg, basereg, off = m.group(1), m.group(2), int(m.group(3),16)
    # look forward for br same reg
    for j in range(i+1, min(i+8, len(insns))):
        t2 = insns[j][1]
        if re.fullmatch(r'br\s+'+reg, t2):
            out.append((a, basereg, off, insns[j][0]))
            break
print("== br-through-table (ldr x,[xb,#off]; ... br x) ==")
for a,b,off,ba in out:
    print(f"load@{a:06x} base={b} slot=+0x{off:x} br@{ba:06x}")

print()
print("== all adrp referencing 0x35000 / 0x36000 with following ldr of a global ==")
for i,(a,t) in enumerate(insns):
    m = re.match(r'adrp\s+(x\d+),\s*0x([0-9a-f]+)', t)
    if not m: continue
    base = int(m.group(2),16)
    if base not in (0x35000,0x36000,0x34000): continue
    nxt = insns[i+1][1] if i+1<len(insns) else ""
    nxt2 = insns[i+2][1] if i+2<len(insns) else ""
    print(f"{a:06x}: {t} | next: {nxt} | {nxt2}")
