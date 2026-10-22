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

print("=== all blr sites with preceding 12 instructions that mention ldr ===")
for i,(a,t) in enumerate(insns):
    if re.fullmatch(r'blr\s+x\d+', t):
        print(f"\n-- blr @ {a:06x}: {t}")
        for j in range(max(0,i-10), i+1):
            if 'ldr' in insns[j][1] or 'adrp' in insns[j][1] or 'add' in insns[j][1] or 'mov' in insns[j][1]:
                print(f"   {insns[j][0]:06x}: {insns[j][1]}")
