#!/usr/bin/env bash
set -u
python3 - <<'PY'
import struct, uuid, lzma, hashlib
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
print("modules",len(a),len(b))
for g in ("9c5e7a31-4b28-4f6d-8a19-2d7c6e5b3a84",):  # VermeerLogDiskDxe, same size both
    x,y=a[g],b[g]
    print(g,"len",len(x),len(y))
    # FFS header 24 bytes then sections; compare header fields
    print(" hdr x",x[:24].hex())
    print(" hdr y",y[:24].hex())
    diffs=[i for i in range(min(len(x),len(y))) if x[i]!=y[i]]
    print(" total diff bytes:",len(diffs),"of",len(x))
    # cluster
    cl=[]
    for i in diffs:
        if cl and i-cl[-1][-1]<=16: cl[-1].append(i)
        else: cl.append([i])
    for c in cl[:12]:
        s,e=c[0],c[-1]
        print(f"  diff @ {s:#06x}..{e:#06x} len {len(c)} | x={x[s:e+1].hex()[:48]} y={y[s:e+1].hex()[:48]}")
PY
