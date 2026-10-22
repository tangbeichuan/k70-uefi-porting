#!/usr/bin/env bash
echo "=== menu155 asm: GCC-related immediates ==="
grep -nE '#0x(100000|f004|f010|f014|f018|f084|f000|502c|8201c|6a004|8c010)' /tmp/menu155.asm | head -20
echo
echo "=== menu155 asm: mov/movk 0x100000 materialisation ==="
grep -nE 'movk?\s+w[0-9]+, #0x(f004|100000|10)\b' /tmp/menu155.asm | head -20
echo
echo "=== menu155: ldr with #0xc1xx / #0xc7xx (DWC3) ==="
grep -cE '#0xc1|#0xc2|#0xc7' /tmp/menu155.asm || true
echo
echo "=== check keys152 SEC vs keys155 SEC: build determinism (rebuild keys152 lineage not tested) ==="
python3 - <<'PY'
import struct, uuid, hashlib
for tag in ("keys154","keys155"):
    p=f"/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-{tag}.fd"
    buf=open(p,'rb').read()
    def u16(b,o): return struct.unpack_from("<H",b,o)[0]
    hdr=buf.find(b"_FVH",0,0x1000); base=hdr-0x28
    off=base+u16(buf,base+0x30)
    while off+0x18<=len(buf):
        ft=buf[off+0x12]; sz=buf[off+0x14]|(buf[off+0x15]<<8)|(buf[off+0x16]<<16)
        if sz<0x18 or ft==0xFF: break
        if ft==0x03:
            body=buf[off+0x18:off+sz]
            print(tag,"SEC size",len(body),"sha",hashlib.sha256(body).hexdigest()[:16])
            break
        off=(off+sz+7)&~7
PY
