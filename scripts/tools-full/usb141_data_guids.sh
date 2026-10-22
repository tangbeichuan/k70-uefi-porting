#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
python3 - <<'PY'
import struct
F='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi'
d=open(F,'rb').read()
def gstr(b):
    a,bb,c=struct.unpack('<IHH',b[:8]); return '%08X-%04X-%04X-%s-%s'%(a,bb,c,b[8:10].hex().upper(),b[10:16].hex().upper())
for off in (0x130c8,0x130d8,0x130e8,0x130f8,0x13108,0x13118,0x13128,0x13138,0x13148,0x13778,0x13788):
    print(hex(off), gstr(d[off:off+16]))
print('--- interface table 0x13470-0x13498 ---')
for i in range(0x13470,0x13498,8):
    print(hex(i), d[i:i+8].hex(), hex(struct.unpack('<Q',d[i:i+8])[0]))
PY
