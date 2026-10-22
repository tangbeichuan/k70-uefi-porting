#!/usr/bin/env bash
set -u
python3 - <<'PY'
import struct, uuid, lzma, hashlib
LZ="ee4e5898-3914-4259-9d6e-dc7bd79403cf"
def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
def gs(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))
def parse_fv(dec, first):
    out={}; io=first
    while io+0x18<=len(dec):
        it=dec[io+0x12]; iz=dec[io+0x14]|(dec[io+0x15]<<8)|(dec[io+0x16]<<16)
        if iz<0x18 or it==0xFF: break
        if it not in (0x0B,0xF0):
            out[gs(dec,io)]=(iz, hashlib.sha256(dec[io:io+iz]).hexdigest()[:16])
        io=(io+iz+7)&~7
    return out
def best_fv(dec):
    base=dec.find(b"_FVH",0,0x1000)-0x28
    hl=u16(dec,base+0x30) if base>=0 else 0x48
    cands=[0x48,0x50,0x78,hl]
    best={}
    for c in cands:
        try: m=parse_fv(dec,c)
        except Exception: m={}
        if len(m)>len(best): best=m
    return best
def fd_modules(path):
    buf=open(path,'rb').read()
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
                return best_fv(lzma.decompress(body[so+u16(body,so+0x14):so+ssz],format=lzma.FORMAT_ALONE))
            so=(so+ssz+3)&~3
        off=(off+sz+7)&~7
    return {}
fv=open("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv","rb").read()
fresh=best_fv(fv)
k152=fd_modules("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152.fd")
k155=fd_modules("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys155.fd")
print("modules fresh",len(fresh),"keys152",len(k152),"keys155",len(k155))
def cmp(name,a,b):
    ch=[g for g in a if g in b and a[g]!=b[g]]
    print(f"{name}: changed={len(ch)} added={len(set(b)-set(a))} removed={len(set(a)-set(b))}")
    return ch
c1=cmp("fresh(keys152ck) vs keys152",fresh,k152)
c2=cmp("fresh(keys152ck) vs keys155",fresh,k155)
c3=cmp("keys155 vs keys152",k155,k152)
print("overlap(fresh-vs-152, keys155-vs-152) =",len(set(c1)&set(c3)))
menu="4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"
print("MENU fresh:",fresh.get(menu),"k152:",k152.get(menu),"k155:",k155.get(menu))
print("\nsample fresh-vs-152 changes:")
for g in c1[:8]: print(" ",g,fresh[g],k152[g])
PY
