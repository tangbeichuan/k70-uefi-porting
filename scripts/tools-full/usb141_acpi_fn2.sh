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
for a,m,o in ins:
    if 0x6e04<=a<=0x6ea8: print('%06x %-8s %s'%(a,m,o))
print('--- strings at 0x10c77 / 0x10d46 / 0x10af5 etc ---')
data=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi','rb').read()
for off in (0x10bb9,0x10bbb,0x10af5,0x10b19,0x10c77,0x10d46,0x1075d):
    e=data.find(b'\0',off); print(hex(off), repr(data[off:e]))
PY
