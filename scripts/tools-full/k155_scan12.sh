#!/usr/bin/env bash
set -u
python3 - <<'PY'
import struct, uuid, lzma, pathlib
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
def pe_of(ffs):
    body=ffs[0x18:]; so=0
    while so+4<=len(body):
        ssz=body[so]|(body[so+1]<<8)|(body[so+2]<<16); st=body[so+3]
        if ssz<4: return None
        if st==0x10:  # PE32
            return body[so+4:so+ssz]
        so=(so+ssz+3)&~3
    return None
a=mods("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152.fd")
b=mods("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys155.fd")
for g,name in (("9c5e7a31-4b28-4f6d-8a19-2d7c6e5b3a84","LogDisk"),("17f55a7f-ddb8-4152-a280-e3984b6eea94","x17f55a7f")):
    pa,pb=pe_of(a[g]),pe_of(b[g])
    print(name,"PE len",len(pa),len(pb),"MZ",pa[:2],pb[:2])
    pathlib.Path(f"/tmp/{name}_152.efi").write_bytes(pa)
    pathlib.Path(f"/tmp/{name}_155.efi").write_bytes(pb)
    # compare .text by pe section table
    import struct as st
    def sections(bimg):
        if bimg[:2]!=b"MZ": return {}
        pe=st.unpack_from("<I",bimg,0x3c)[0]
        n=st.unpack_from("<H",bimg,pe+6)[0]; opt=st.unpack_from("<H",bimg,pe+20)[0]
        base=pe+24+opt; out={}
        for i in range(n):
            o=base+i*40
            nm=bimg[o:o+8].rstrip(b"\x00").decode(errors="replace")
            vs=st.unpack_from("<I",bimg,o+8)[0]; va=st.unpack_from("<I",bimg,o+12)[0]
            rs=st.unpack_from("<I",bimg,o+16)[0]; ro=st.unpack_from("<I",bimg,o+20)[0]
            out[nm]=bimg[ro:ro+rs]
        return out
    sa,sb=sections(pa),sections(pb)
    for nm in sorted(set(sa)&set(sb)):
        print(f"   {nm:8s} {len(sa[nm]):7d}/{len(sb[nm]):7d} identical={sa[nm]==sb[nm]}")
    # timestamp in PE header
    if pa[:2]==b"MZ":
        pe=st.unpack_from("<I",pa,0x3c)[0]
        print("   timestamps",hex(st.unpack_from("<I",pa,pe+8)[0]),hex(st.unpack_from("<I",pb,pe+8)[0]))
PY
echo
echo "=== disassembly .text hash compare ==="
for n in LogDisk_152 LogDisk_155; do
  llvm-objdump -d --section=.text /tmp/$n.efi 2>/dev/null | sed -E 's/^ *[0-9a-f]+://' > /tmp/$n.txt || true
done
if [ -s /tmp/LogDisk_152.txt ] && [ -s /tmp/LogDisk_155.txt ]; then
  sed -E 's/^ *[0-9a-f]+://' /tmp/LogDisk_152.txt | md5sum
  sed -E 's/^ *[0-9a-f]+://' /tmp/LogDisk_155.txt | md5sum
  diff <(sed -E 's/^ *[0-9a-f]+://' /tmp/LogDisk_152.txt) <(sed -E 's/^ *[0-9a-f]+://' /tmp/LogDisk_155.txt) | head -20
else
  llvm-objdump -d /tmp/LogDisk_152.efi 2>/dev/null | sed -E 's/^ *[0-9a-f]+://' > /tmp/L152.txt
  llvm-objdump -d /tmp/LogDisk_155.efi 2>/dev/null | sed -E 's/^ *[0-9a-f]+://' > /tmp/L155.txt
  echo "text lines: $(wc -l < /tmp/L152.txt) / $(wc -l < /tmp/L155.txt)"
  diff /tmp/L152.txt /tmp/L155.txt | head -20
  md5sum /tmp/L152.txt /tmp/L155.txt
fi
