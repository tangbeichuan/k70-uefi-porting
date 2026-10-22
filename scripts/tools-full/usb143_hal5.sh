#!/bin/bash
set -e
python3 - <<'PY'
import re
F='/tmp/hal.asm'
ins=[]
for L in open(F):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)',L)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
slots={}
for i,(a,m,o) in enumerate(ins):
    if m=='ldr':
        mm=re.match(r'(x\d+), \[(x\d+), #(0x[0-9a-f]+)\]',o)
        if not mm: continue
        dst,base,off=mm.group(1),mm.group(2),int(mm.group(3),16)
        # find where base was loaded from 0x280 / 0x2b8 (DTBExtn iface cache globals)
        for j in range(max(0,i-10),i):
            aj,mj,oj=ins[j]
            if mj=='ldr' and oj.startswith(base+', '):
                m2=re.match(r'x\d+, \[(x\d+), #0x(?:280|2b8|190)\]',oj)
                if m2:
                    slots.setdefault(off,[]).append(a)
for off in sorted(slots):
    print('slot +0x%02x : %d refs  %s'%(off,len(slots[off]),' '.join(hex(x) for x in slots[off][:8])))
PY
