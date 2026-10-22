#!/usr/bin/env bash
set -u
OUT=/tmp/menu155.asm
[ -s "$OUT" ] || llvm-objdump -d /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi > "$OUT"
echo "=== MMIO stores (str/strb whose base is not sp) ==="
grep -nE 'str(b|h)?[[:space:]]+w[0-9]+, \[x[0-9]+' "$OUT" | head -20
echo "--- total str to [xN]: $(grep -cE 'str(b|h)?[[:space:]]+w[0-9]+, \[x[0-9]+' "$OUT" || true); total str to [sp]: $(grep -cE 'str(b|h)?[[:space:]]+(w|x)[0-9]+, \[sp' "$OUT" || true)"
echo
python3 - <<'PY'
import struct, uuid, lzma
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
                doff=so+u16(body,so+0x14)
                dec=lzma.decompress(body[doff:so+ssz],format=lzma.FORMAT_ALONE)
                io=0x50
                while io+0x18<=len(dec):
                    it=dec[io+0x12]; iz=dec[io+0x14]|(dec[io+0x15]<<8)|(dec[io+0x16]<<16)
                    if iz<0x18 or it==0xFF: break
                    if it not in (0x0B,0xF0): out[gs(dec,io)]=dec[io+0x18:io+iz]
                    io=(io+iz+7)&~7
                return out
            so=(so+ssz+3)&~3
        off=(off+sz+7)&~7
    return out
a=mods("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152.fd")
b=mods("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys155.fd")
for g in ("17f55a7f-ddb8-4152-a280-e3984b6eea94","4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"):
    x,y=a[g],b[g]
    i=next((k for k in range(min(len(x),len(y))) if x[k]!=y[k]),None)
    print(g,"size",len(x),"->",len(y),"first_diff",hex(i) if i is not None else None)
    if i is not None:
        print("  x:",x[max(0,i-16):i+32].hex())
        print("  y:",y[max(0,i-16):i+32].hex())
    # locate common suffix
    for back in (64,128,256,512,1024):
        tail=y[-back:]
        p=x.find(tail)
        if p>=0:
            print(f"  y tail {back}B found in x at {p:#x} (x len {len(x)})")
            break
PY
