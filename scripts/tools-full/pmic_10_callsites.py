#!/usr/bin/env python3
# pmic_10_callsites.py : show context before each call to a target function
import sys, re

path = '/tmp/pmic/pmic.asm'
lines = open(path, encoding='utf-8', errors='replace').read().splitlines()

target = sys.argv[1].lower()
ctx = int(sys.argv[2]) if len(sys.argv) > 2 else 12

insns = []  # (addr, text)
for ln in lines:
    m = re.match(r'\s*([0-9a-f]{4,8}):\s+([0-9a-f]{8})\s+(.*)', ln)
    if m:
        try:
            a = int(m.group(1), 16)
        except ValueError:
            continue
        insns.append((a, m.group(3).strip()))

for i, (a, t) in enumerate(insns):
    if re.search(r'\b(bl|b)\s+0x' + target.lstrip('0x') + r'\b', t):
        print('=== %08x: %s' % (a, t))
        for j in range(max(0, i-ctx), i+1):
            print('   %08x: %s' % (insns[j][0], insns[j][1]))
        print()
