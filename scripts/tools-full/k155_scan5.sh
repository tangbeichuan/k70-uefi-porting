#!/usr/bin/env bash
# Compare the SEC/PEI FFS of keys92/93 (lead says keys93 = 44 regions incl GCC, booted)
python3 - <<'PY'
import struct, uuid, hashlib

def gstr(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))
def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]

def sec_ffs(path):
    buf=open(path,'rb').read()
    hdr=buf.find(b"_FVH",0,0x1000); base=hdr-0x28
    off=base+u16(buf,base+0x30); end=min(len(buf),base+u64(buf,base+0x20))
    while off+0x18<=end:
        ft=buf[off+0x12]; sz=buf[off+0x14]|(buf[off+0x15]<<8)|(buf[off+0x16]<<16)
        if sz<0x18 or ft==0xFF: break
        if ft==0x03:
            body=buf[off+0x18:off+sz]
            return gstr(buf,off), body
        off=(off+sz+7)&~7
    return None,None

for tag in ["keys90","keys91","keys92","keys93","keys94","keys95"]:
    p=f"/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-{tag}.fd"
    try:
        g,body=sec_ffs(p)
    except FileNotFoundError:
        print(f"{tag}: missing"); continue
    if body is None:
        print(f"{tag}: no SEC FFS"); continue
    print(f"{tag}: SEC guid={g} size={len(body)} sha={hashlib.sha256(body).hexdigest()[:16]}")
    for name in (b"GCC\x00", b"USB\x00", b"PERIPH_SS\x00", b"UFS\x00"):
        print(f"     {name!r}: {body.count(name)}")
PY
