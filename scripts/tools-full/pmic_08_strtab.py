#!/usr/bin/env python3
import struct
EFI="/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi"
data=open(EFI,"rb").read()
def cstr(off, maxn=300):
    if off<0 or off>=len(data): return f"<out {off:x}>"
    end=data.find(b'\x00', off)
    if end<0: end=len(data)
    b=data[off:end]
    try: s=b.decode('utf-8','replace')
    except: s=repr(b)
    return s[:maxn]
def dump(off,n):
    for i in range(0,n,16):
        ch=data[off+i:off+i+16]
        asc=''.join(chr(c) if 32<=c<127 else '.' for c in ch)
        print(f"{off+i:06x}: {ch.hex(' '):<48} {asc}")

print("=== table at 0x35238 ===")
for i in range(0,20):
    off=0x35238+i*8
    v=struct.unpack_from("<Q",data,off)[0]
    print(f"  [{off:06x}] idx {i} = 0x{v:06x}  -> {cstr(v) if 0x1000<=v<0x3a000 else ''}")
print()
print("=== raw around 0x35220-0x35300 ===")
dump(0x35220,0xe0)
print()
print("=== strings near table targets ===")
for i in range(0,10):
    v=struct.unpack_from("<Q",data,0x35238+i*8)[0]
    if 0x1000<=v<0x3a000:
        print(f"idx {i}: 0x{v:06x} len={len(cstr(v))} content={cstr(v)!r}")
