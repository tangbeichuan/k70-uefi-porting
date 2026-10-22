#!/usr/bin/env python3
import struct, re
EFI="/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi"
data=open(EFI,"rb").read()
print("filesize", hex(len(data)))
def hexdump(off, n, base=None):
    for i in range(0,n,16):
        chunk=data[off+i:off+i+16]
        asc=''.join(chr(c) if 32<=c<127 else '.' for c in chunk)
        print(f"{off+i:06x}: {chunk.hex(' '):<48} {asc}")

# probe suspected GUIDs
for off in (0x2f2f8, 0x2f268, 0x2f800):
    print(f"--- probe {off:x}")
    hexdump(off, 0x30)

# scan .data for known GUID 0389B776-625F-11EB-83BE-C741A913DE34 (little endian)
guid=bytes.fromhex("76b78903 5f62 eb11 83be c741a913de34".replace(" ",""))
print("DTBExtn GUID bytes:", guid.hex())
for i in range(0x2f000,0x3a000-16):
    if data[i:i+16]==guid: print("found DTBExtn GUID at", hex(i))
# also fdt table guid b1b621d5-f19c-41a5-830b-d9152c69aae0
g2=bytes.fromhex("d521b6b1 9cf1 a541 830b d9152c69aae0".replace(" ",""))
for i in range(0x2f000,0x3a000-16):
    if data[i:i+16]==g2: print("found FDT table GUID at", hex(i))
