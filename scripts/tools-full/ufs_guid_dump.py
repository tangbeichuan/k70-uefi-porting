#!/usr/bin/env python3
import struct, subprocess, re
EFI='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi'
d=open(EFI,'rb').read()
g=d[0x1b278:0x1b288]
def fmt(b):
    d1,d2,d3=struct.unpack('<IHH',b[:8])
    return '%08X-%04X-%04X-%s-%s'%(d1,d2,d3,b[8:10].hex().upper(),b[10:16].hex().upper())
print('DTBExtn protocol GUID =', fmt(g))
print('raw:', g.hex())
# also check the global interface pointer location 0x1f018 -> what's there
print('data @0x1f018 (va) file off', hex(0x1b000+(0x1f018-0x1c000)))
print(d[0x1b000+(0x1f018-0x1c000):0x1b000+(0x1f018-0x1c000)+32].hex())
print()
dis=subprocess.run(['llvm-objdump','-d','--no-show-raw-insn',EFI],capture_output=True,text=True).stdout
lines=dis.splitlines()
start=None
for i,l in enumerate(lines):
    if re.match(r'^\s*172c4:', l): start=i; break
for k in range(start, start+80):
    print(lines[k])
