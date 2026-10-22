#!/bin/bash
set -e
for mod in UsbfnDwc3Dxe UsbInitDxe; do
F=$(find /root/k70/uefi/Binaries/vermeer -iname "$mod.patched.efi" -o -iname "$mod.efi" | head -1)
echo "=== $mod $F"
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/$mod.asm 2>/dev/null || true
python3 - "$mod" <<'PY'
import re,sys
mod=sys.argv[1]
lines=open('/tmp/%s.asm'%mod).read().splitlines()
ins=[]
for L in lines:
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', L)
    if m: ins.append((int(m.group(1),16), m.group(2), m.group(3).strip()))
import struct,glob,os
cands=glob.glob('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/%s/%s*.efi'%(mod,mod))
path=cands[0]
print('using',path)
data=open(path,'rb').read()
g=struct.pack('<IHH',0xE722B03F,0xB250,0x42CE)+bytes.fromhex('8EBD5BD51812D037')
offs=[i for i in range(len(data)) if data[i:i+16]==g]
print('guid file offsets:', [hex(o) for o in offs])
for off in offs:
    # find adrp/add referencing this VA (VA==fileoff)
    for i,(a,m,o) in enumerate(ins):
        if m=='adrp' and '0x13000' in o and off<0x14000:
            pass
    for i,(a,m,o) in enumerate(ins):
        if m=='adrp':
            mm=re.match(r'(x\d+), 0x([0-9a-f]+)', o)
            if not mm: continue
            page=int(mm.group(2),16)
            for j in range(i+1,min(i+3,len(ins))):
                a2,m2,o2=ins[j]
                if m2=='add':
                    m3=re.match(r'(x\d+), x\d+, #(0x[0-9a-f]+)', o2)
                    if m3 and page+int(m3.group(2),16)==off:
                        print('  ref at',hex(a),o,'/',o2)
                        for k in range(j+1,min(j+8,len(ins))):
                            print('    ',hex(ins[k][0]),ins[k][1],ins[k][2])
PY
done
