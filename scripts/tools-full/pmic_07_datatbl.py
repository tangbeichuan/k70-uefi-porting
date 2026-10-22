#!/usr/bin/env python3
import struct
EFI="/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi"
data=open(EFI,"rb").read()
TEXTL=0x1000; TEXTH=0x2f000
hits=[]
for off in range(0x2f000,0x3a000-8):
    v=struct.unpack_from("<Q",data,off)[0]
    if TEXTL<=v<TEXTH:
        hits.append((off,v))
print(f"{len(hits)} qword pointers into .text in .data")
for off,v in hits:
    # find nearby strings
    print(f"  data[{off:06x}] = 0x{v:06x}")
