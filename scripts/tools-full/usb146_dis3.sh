#!/bin/bash
# usb146_dis3.sh -- HALIOMMU install site, GUID producers in FV, function start 0x3e00-0x3f68
set -u
python3 - /tmp/ucfg145.efi <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read()
pe=d.find(b"PE\x00\x00"); nsec=struct.unpack_from("<H",d,pe+6)[0]
opt=pe+24; magic=struct.unpack_from("<H",d,opt)[0]
secs=[]
so=opt+(0xf0 if magic==0x20b else 0xe0)
for i in range(nsec):
    s=so+i*40; name=d[s:s+8].rstrip(b"\0").decode()
    vsize,va,rsize,raw=struct.unpack_from("<IIII",d,s+8)
    secs.append((name,va,vsize,raw,rsize))
print("UsbConfigDxe sections:",secs)
PY
echo
echo "===== UsbConfigDxe 0x3E00-0x3F70 ====="
llvm-objdump -d --start-address=0x3e00 --stop-address=0x3f70 /tmp/ucfg145.efi
echo
echo "===== FVMAIN GUID 54B6D3B4 occurrences -> modules ====="
python3 /mnt/d/本地项目-01/_tools/usb146_guidmap.py 2>/dev/null || python3 - <<'PY'
import struct,uuid
FV="/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
fv=open(FV,'rb').read()
hdr=fv.find(b"_FVH",0,0x1000); base=hdr-0x28
hdrlen=struct.unpack_from("<H",fv,base+0x30)[0]
off=base+hdrlen
mods=[]
while off+0x18<=len(fv):
    t=fv[off+0x12]; size=fv[off+0x14]|(fv[off+0x15]<<8)|(fv[off+0x16]<<16)
    if size<0x18 or t==0xFF: break
    mods.append((off,off+size,str(uuid.UUID(bytes_le=fv[off:off+16]))))
    off=(off+size+7)&~7
pat=bytes.fromhex('b4d3b654335d914f86006c41d5deb19a')
i=0
while True:
    i=fv.find(pat,i)
    if i<0: break
    owners=[m for m in mods if m[0]<=i<m[1]]
    print("  GUID @0x%x -> %s"%(i,owners[0][2] if owners else "?"))
    i+=1
PY
echo
echo "===== HALIOMMU: instructions referencing GUID page 0xd000 ====="
grep -n -E "adrp\s+x[0-9]+, 0xd000|#0x68\s*$" /tmp/hal146.asm | head -20
echo
echo "===== HALIOMMU: who calls with GUID at 0xd068 (context) ====="
python3 - <<'PY'
import re
lines=open('/tmp/hal146.asm',errors='ignore').read().splitlines()
idx=[i for i,l in enumerate(lines) if re.search(r'#0x68\s*$',l)]
for i in idx[:6]:
    for j in range(max(0,i-8),min(len(lines),i+10)):
        print(lines[j])
    print("---")
PY
