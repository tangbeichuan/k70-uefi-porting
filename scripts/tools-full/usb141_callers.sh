#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/usbcfg.asm
python3 - <<'PY'
import re
lines=open('/tmp/usbcfg.asm').read().splitlines()
ins=[]
for L in lines:
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', L)
    if m: ins.append((int(m.group(1),16), m.group(2), m.group(3).strip()))
def show(lo,hi):
    for a,m,o in ins:
        if lo<=a<=hi: print('%06x %-8s %s'%(a,m,o))
# callers of 0x6e60 (ACPI patch func) and 0x7150 (RegisterNotify func)
for target in (0x6e60,0x7150):
    print('=== callers of', hex(target))
    for i,(a,m,o) in enumerate(ins):
        if m in ('bl','b') and re.search(r'\b0x%x\b'%target, o):
            print('--- caller at', hex(a))
            show(max(0,a-0x50), a+0x10)
# find entrypoint: look for function that references 'UsbConfigDriverEntryPoint' string? just dump strings block
data=open(F,'rb').read()
i=data.find(b'UsbConfigDriverEntryPoint')
print('entry name str at', hex(i) if i>=0 else 'n/a')
PY
