#!/bin/bash
set -e
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
llvm-objdump -d --no-show-raw-insn "$EFI" > /tmp/usbcfg.asm
python3 - <<'PY'
import re
lines=open('/tmp/usbcfg.asm').read().splitlines()
ins=[]
for L in lines:
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', L)
    if m: ins.append((int(m.group(1),16), m.group(2), m.group(3).strip()))
print('total insns', len(ins))
for i,(a,m,o) in enumerate(ins):
    if m=='adrp' and o.startswith('x8, 0x13000'):
        for j in range(i+1, min(i+4,len(ins))):
            a2,m2,o2=ins[j]
            mm=re.match(r'x8, \[x8, #(0x[0-9a-f]+)\]', o2)
            if m2=='ldr' and mm and int(mm.group(1),16)==0x7c8:
                print('=== gSdt load at', hex(a))
                for k in range(j+1, min(j+14,len(ins))):
                    ak,mk,ok=ins[k]
                    print('   ', hex(ak), mk, ok)
                break
PY
