#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/hal.asm
python3 - <<'PY'
import struct,re
F='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi'
d=open(F,'rb').read()
def pat(s):
    a,b,c,dd,e,f,g,h,=0,0,0,0,0,0,0,0
    return None
g=struct.pack('<IHH',0x0389B776,0x625F,0x11EB)+bytes.fromhex('83BEC741A913DE34')
offs=[]
i=d.find(g)
while i>=0:
    offs.append(i); i=d.find(g,i+1)
print('DTBExtn GUID file offsets:',[hex(o) for o in offs])
ins=[]
for L in open('/tmp/hal.asm'):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)',L)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
for off in offs:
    for idx,(a,m,o) in enumerate(ins):
        if m=='adrp':
            mm=re.match(r'(x\d+), 0x([0-9a-f]+)',o)
            if not mm: continue
            page=int(mm.group(2),16)
            for j in range(idx+1,min(idx+6,len(ins))):
                a2,m2,o2=ins[j]
                if m2=='add':
                    m3=re.match(r'(x\d+), x\d+, #(0x[0-9a-f]+)',o2)
                    if m3 and page+int(m3.group(2),16)==off:
                        print('--- ref @',hex(a),'(',o,'/',o2,')')
                        for k in range(max(0,idx-6),min(j+10,len(ins))):
                            print('   ',hex(ins[k][0]),ins[k][1],ins[k][2])
PY
