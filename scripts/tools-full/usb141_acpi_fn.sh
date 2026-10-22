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

def dump(lo,hi,title):
    print('===',title)
    for a,m,o in ins:
        if lo<=a<=hi: print('%06x %-8s %s'%(a,m,o))

dump(0x6cf0,0x6e04,'before ACPI func')
# find function start: scan back for ret/udf
PY
