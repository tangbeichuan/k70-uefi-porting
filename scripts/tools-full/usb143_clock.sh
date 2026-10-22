#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
python3 - "$F" <<'PY'
import struct,sys,re
F=sys.argv[1]
d=open(F,'rb').read()
def gstr(b):
    a,bb,c=struct.unpack('<IHH',b[:8]); return '%08X-%04X-%04X-%s-%s'%(a,bb,c,b[8:10].hex().upper(),b[10:16].hex().upper())
print("GUID @0x131b8 :", gstr(d[0x131b8:0x131c8]))
print("GUID @0x131a8 :", gstr(d[0x131a8:0x131b8]))
print("global 0x13760..0x13790:")
for i in range(0x13760,0x13790,8):
    v=struct.unpack('<Q',d[i:i+8])[0]; print("  %04x = 0x%x"%(i-0x1000,v))
def cstr(off):
    e=d.find(b'\0',off); return d[off:e].decode('latin1')
print("--- strings ---")
for off in (0x1005a,0x100db,0x10109,0x10150,0x101a0,0x10230,0x102d0,0x10310):
    print("  0x%05x: %r"%(off,cstr(off)))
print("--- all ascii runs 0x10040-0x101c0 ---")
i=0x10040
while i<0x101c0:
    if 32<=d[i]<127 and (i==0x10040 or d[i-1]==0):
        s=cstr(i)
        if len(s)>=4: print("  0x%05x: %r"%(i,s))
        i+=len(s)+1
    else: i+=1
PY
echo "=== refs to global 0x13768 / guid 0x131b8 / strings ==="
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/ucfg.asm
python3 - <<'PY'
import re
ins=[]
for L in open('/tmp/ucfg.asm'):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', L)
    if m: ins.append((int(m.group(1),16), m.group(2), m.group(3).strip()))
targets={0x13768:'gClockGlobal(0x13768)',0x131b8:'GUID@0x131b8',0x131a8:'GUID@0x131a8',
         0x100db:'str@0x100db',0x10109:'str@0x10109',0x1005a:'str@0x1005a'}
for i,(a,m,o) in enumerate(ins):
    if m in ('adrp','add') and i+1<len(ins):
        pass
# resolve adrp/add pairs
for i,(a,m,o) in enumerate(ins):
    if m!='adrp': continue
    mm=re.match(r'(x\d+), 0x([0-9a-f]+)', o)
    if not mm: continue
    page=int(mm.group(2),16)
    for j in range(i+1,min(i+3,len(ins))):
        a2,m2,o2=ins[j]
        if m2=='add':
            m3=re.match(r'(x\d+), x\d+, #(0x[0-9a-f]+)', o2)
            if m3 and page+int(m3.group(2),16) in targets:
                t=page+int(m3.group(2),16)
                print("  %s used at 0x%x (%s)"%(targets[t],a,ins[i][2]))
PY
