#!/bin/bash
set -e
python3 - <<'PY'
import struct
p='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi'
d=open(p,'rb').read()
for off in (0x3fa4,0x3fa8,0x3ff0):
    u=struct.unpack('<I',d[off:off+4])[0]
    print(hex(off), d[off:off+4].hex(), '0x%08X'%u)
PY
