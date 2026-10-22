#!/bin/bash
# keys144 pre-analysis: DTBExtn usage + runtime protocol table of the USB device-mode chain
set -e
BIN=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
for M in UsbfnDwc3Dxe UsbDeviceDxe UsbInitDxe UsbMsdDxe UsbBusDxe UsbPwrCtrlDxe; do
  F=$(ls $BIN/$M/$M*.efi 2>/dev/null | head -1)
  [ -z "$F" ] && { echo "=== $M: NO EFI"; continue; }
  echo "================ $M ($F)"
  llvm-objdump -d --no-show-raw-insn "$F" > /tmp/$M.asm 2>/dev/null
  python3 - "$M" <<'PY'
import re,sys
M=sys.argv[1]
data=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/%s/%s.efi'%(M,M),'rb').read()
ins=[]
for L in open('/tmp/%s.asm'%M):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)',L)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
def cstr(off,n=56):
    e=data.find(b'\x00',off)
    try: return data[off:e].decode('ascii')
    except Exception: return '?'
print(' dtb guid present:', bytes.fromhex('76b78903')+bytes.fromhex('5f62eb11')+bytes.fromhex('83bec741a913de34') in data)
slots={'0x28','0x30','0x58','0x68','0x70','0x88','0x90','0x98','0xa0','0xa8','0xc8','0xe0'}
hist={}
found=[]
for i,(a,m,o) in enumerate(ins):
    if m!='ldr': continue
    mm=re.match(r'(x\d+), \[(x\d+), #(0x[0-9a-f]+)\]',o)
    if not mm: continue
    dst,base,slot=mm.group(1),mm.group(2),mm.group(3)
    if slot not in slots: continue
    # must be followed by blr dst and the base must have been loaded from a global (interface ptr)
    if i+1>=len(ins) or ins[i+1][1]!='blr': continue
    if ins[i+1][2].split(',')[0].strip()!=dst: continue
    hist[slot]=hist.get(slot,0)+1
    # collect nearby string refs (x1 = adrp+add) in previous 30 insns
    strs=[]
    for j in range(max(0,i-40),i):
        if ins[j][1]=='add':
            m3=re.match(r'x1, x\d+, #(0x[0-9a-f]+)',ins[j][2])
            if m3:
                for k in range(j-1,max(0,j-4),-1):
                    if ins[k][1]=='adrp' and ins[k][2].startswith('x'):
                        pg=re.search(r'0x([0-9a-f]+)',ins[k][2])
                        if pg:
                            so=int(pg.group(1),16)+int(m3.group(1),16)
                            s=cstr(so)
                            if s and all(32<=ord(c)<127 for c in s): strs.append(s)
                            break
    if strs: found.append((a,slot,strs[-1]))
print(' slot histogram:', ' '.join('%s=%d'%(k,v) for k,v in sorted(hist.items())))
for a,slot,s in found[:80]:
    print('   %-6s +%-5s "%s"'%(hex(a),slot,s))
# all ascii strings that look like DT paths / property names
print(' --- strings with /soc or usb-ish paths ---')
import re as _re
for m in _re.finditer(rb'/soc/[A-Za-z0-9_@/.-]{2,60}', data):
    print('   ',m.group().decode())
PY
done
