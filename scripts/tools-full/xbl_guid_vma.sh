#!/bin/bash
# Locate the DTBExtn GUID inside xbl_a.img (ELF) and report where it lives.
set -e
XBL=/root/k70/rt/xbl_a.img
if [ ! -f "$XBL" ]; then
  mkdir -p /root/k70/rt
  cp "/mnt/d/本地项目-01/.dsh-im/inbound/20261020-183502-SmiQOg/01-06f41ecb-3e57-4f10-be7c-31aade36d0e2_xbl_a.img" "$XBL" 2>/dev/null || \
  cp /mnt/d/本地项目-01/.dsh-im/inbound/20261020-183502-SmiQOg/*xbl_a.img "$XBL"
fi
echo "xbl: $(stat -c%s "$XBL") bytes"
python3 - <<'PY'
import struct
p='/root/k70/rt/xbl_a.img'
b=open(p,'rb').read()
# little-endian GUID bytes for 0389B776-625F-11EB-83BE-C741A913DE34
guid = bytes([0x76,0xB7,0x89,0x03, 0x5F,0x62, 0xEB,0x11, 0x83,0xBE, 0xC7,0x41,0xA9,0x13,0xDE,0x34])
hits=[]
i=0
while True:
    p0=b.find(guid,i)
    if p0<0: break
    hits.append(p0); i=p0+1
print("GUID file offsets:", [hex(h) for h in hits])

# ELF program headers -> map file offset to VMA
e_phoff=struct.unpack_from('<Q',b,0x20)[0]
e_phentsize,e_phnum=struct.unpack_from('<HH',b,0x36)
segs=[]
for k in range(e_phnum):
    o=e_phoff+k*e_phentsize
    p_type,p_flags=struct.unpack_from('<II',b,o)
    p_offset,p_vaddr,p_paddr,p_filesz,p_memsz=struct.unpack_from('<QQQQQ',b,o+8)
    if p_type==1:
        segs.append((p_offset,p_vaddr,p_filesz,p_flags))
print("PT_LOAD segments:")
for s in segs: print(f"  off=0x{s[0]:x} vma=0x{s[1]:x} filesz=0x{s[2]:x} flags={s[3]}")
for h in hits:
    for (o,v,sz,fl) in segs:
        if o<=h<o+sz:
            print(f"  GUID @file 0x{h:x} -> VMA 0x{v+(h-o):x}  (seg off=0x{o:x})")
PY
