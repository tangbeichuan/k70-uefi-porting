#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/hal.asm
python3 - <<'PY'
import re,struct
data=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi','rb').read()
ins=[]
for L in open('/tmp/hal.asm'):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)',L)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
def cstr(off, n=48):
    e=data.find(b'\x00',off)
    s=data[off:e]
    return s.decode('ascii','replace') if e>off else '?'
slots={'0x28','0x30','0x58','0x68','0x70','0x90','0x98','0xa0','0xa8','0xc8','0xe0'}
# find call sites: ldr xN,[xM,#slot] ; blr xN
for i,(a,m,o) in enumerate(ins):
    if m!='ldr': continue
    mm=re.match(r'(x\d+), \[(x\d+), #(0x[0-9a-f]+)\]',o)
    if not mm: continue
    dst,base,off=mm.group(1),mm.group(2),mm.group(3)
    if off not in slots: continue
    if i+1>=len(ins) or ins[i+1][1]!='blr' or ins[i+1][2].split(',')[0].strip()!=dst: continue
    # walk backwards to find x1/x2 setup inside this block
    args={}
    for j in range(max(0,i-24),i):
        aj,mj,oj=ins[j]
        mm2=re.match(r'(x[123]), (.*)',oj)
        if not mm2: continue
        reg=mm2.group(1)
        val=mm2.group(2)
        if mj=='add':
            m3=re.match(r'x\d+, (x\d+), #(0x[0-9a-f]+)',val)
            if m3:
                # find adrp setting that base reg
                for k in range(j-1,max(0,j-4),-1):
                    if ins[k][1]=='adrp' and ins[k][2].startswith(m3.group(1)+','):
                        page=int(re.search(r'0x([0-9a-f]+)',ins[k][2]).group(1),16)
                        args[reg]='"%s" @0x%x'%(cstr(page+int(m3.group(2),16)),page+int(m3.group(2),16))
                        break
    print('%-6s +%-5s x0=%s x1=%s x2=%s'%(hex(a),off,args.get('x0','?'),args.get('x1','?'),args.get('x2','?')))
PY
