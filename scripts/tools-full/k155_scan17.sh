#!/usr/bin/env bash
set -u
python3 - <<'PY'
import struct, uuid, lzma, hashlib, re
LZ="ee4e5898-3914-4259-9d6e-dc7bd79403cf"
def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
def gs(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))
def mods(path):
    buf=open(path,'rb').read(); out={}
    hdr=buf.find(b"_FVH",0,0x1000); base=hdr-0x28
    off=base+u16(buf,base+0x30); end=base+u64(buf,base+0x20)
    while off+0x18<=end:
        ft=buf[off+0x12]; sz=buf[off+0x14]|(buf[off+0x15]<<8)|(buf[off+0x16]<<16)
        if sz<0x18 or ft==0xFF: break
        body=buf[off+0x18:off+sz]; so=0
        while so+4<=len(body):
            ssz=body[so]|(body[so+1]<<8)|(body[so+2]<<16); st=body[so+3]
            if ssz<4: break
            if st==0x02 and gs(body,so+4)==LZ:
                dec=lzma.decompress(body[so+u16(body,so+0x14):so+ssz],format=lzma.FORMAT_ALONE)
                io=0x50
                while io+0x18<=len(dec):
                    it=dec[io+0x12]; iz=dec[io+0x14]|(dec[io+0x15]<<8)|(dec[io+0x16]<<16)
                    if iz<0x18 or it==0xFF: break
                    if it not in (0x0B,0xF0): out[gs(dec,io)]=dec[io:io+iz]
                    io=(io+iz+7)&~7
                return out
            so=(so+ssz+3)&~3
        off=(off+sz+7)&~7
    return out
a=mods("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152.fd")
b=mods("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys155.fd")
print("=== drift module payload scan for region-table markers ===")
for g in ("80cf7257-87ab-47f9-a3fe-d50b76d89541","9c5e7a31-4b28-4f6d-8a19-2d7c6e5b3a84","17f55a7f-ddb8-4152-a280-e3984b6eea94"):
    x,y=a[g],b[g]
    print(g, "len",len(x),len(y))
    for name in (b"PERIPH_SS", b"USB", b"IMEM", b"DXE", b"0x0A600000"):
        cx, cy = x.count(name), y.count(name)
        print(f"   {name!r}: {cx} -> {cy}")
    # little endian 0x0A600000
    v=struct.pack("<I",0x0A600000)
    print(f"   le 0x0A600000: {x.count(v)} -> {y.count(v)}")
    # any 'GCC' string inside the payload?
    print(f"   b'GCC': {x.count(b'GCC')} -> {y.count(b'GCC')}")
PY
