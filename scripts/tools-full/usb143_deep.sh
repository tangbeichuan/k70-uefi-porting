#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/ucfg.asm
python3 - <<'PY'
import re,struct
ins=[]
for L in open('/tmp/ucfg.asm'):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', L)
    if m: ins.append((int(m.group(1),16), m.group(2), m.group(3).strip()))
print("=== all refs to gIommu global 0x13768 (adrp/add) ===")
for i,(a,m,o) in enumerate(ins):
    if m!='adrp': continue
    mm=re.match(r'(x\d+), 0x([0-9a-f]+)', o)
    if not mm: continue
    page=int(mm.group(2),16)
    for j in range(i+1,min(i+3,len(ins))):
        a2,m2,o2=ins[j]
        if m2=='add':
            m3=re.match(r'(x\d+), x\d+, #(0x[0-9a-f]+)', o2)
            if m3 and page+int(m3.group(2),16) in (0x13768,0x13770,0x13778):
                print("  ref 0x%x -> 0x%x"%(a,page+int(m3.group(2),16)))
print("=== code 0x41a0-0x4260 ===")
for a,m,o in ins:
    if 0x41a0<=a<=0x4260: print("  %05x %-8s %s"%(a,m,o))
print("=== find function prologue containing 0x3f68 (backward scan) ===")
starts=[]
for i,(a,m,o) in enumerate(ins):
    if m=='sub' and o.startswith('sp, sp, #'):
        # check next ins stp x29
        if i+1<len(ins) and ins[i+1][1] in ('stp',) and 'x29' in ins[i+1][2]:
            starts.append(a)
prev=[s for s in starts if s<=0x3f68]
print("  candidate function starts near 0x3f68:", [hex(x) for x in prev[-4:]])
print("=== calls to function containing 0x3f68 ===")
if prev:
    fstart=prev[-1]
    print("  fstart=0x%x"%fstart)
PY
echo "=== ClockProtocol unavailable string location ==="
python3 - <<'PY'
d=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi','rb').read()
s=b'ClockProtocol unavailable'
i=d.find(s)
print('  file off 0x%x'%i, repr(d[max(0,i-80):i+40]))
PY
echo "=== HALIOMMUDxe ascii node paths ==="
strings -t x /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi | grep -E "^ *[0-9a-f]+ /|soc/|iommu|ctx|domain" | head -40
