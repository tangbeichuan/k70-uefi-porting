#!/bin/bash
set -e
echo "=== find GUID 54B6D3B4-5D33-4F91-8600-6C41D5DEB19A in tree (efi/inf/dec/depex) ==="
python3 - <<'PY'
import struct,os,glob
g=struct.pack('<IHH',0x54B6D3B4,0x5D33,0x4F91)+bytes.fromhex('86006C41D5DEB19A')
roots=['/root/k70/uefi/Binaries','/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV',
       '/mnt/d/本地项目-01/_k70port_extract/fv_dump']
hits=[]
for r in roots:
    for dp,dn,fn in os.walk(r):
        for f in fn:
            p=os.path.join(dp,f)
            try:
                d=open(p,'rb').read()
            except Exception: continue
            c=d.count(g)
            if c: hits.append((p,c,len(d)))
for p,c,s in hits: print("  %-110s count=%d size=%d"%(p,c,s))
print("total files with GUID:",len(hits))
PY
echo "=== grep name in dec files ==="
grep -rn "54B6D3B4\|54B6D3B4" /root/k70/uefi --include=*.dec --include=*.dsc --include=*.inc --include=*.inf 2>/dev/null | head
grep -rni "HalIommu" /root/k70/uefi --include=*.dec 2>/dev/null | head -20
echo "=== HALIOMMU driver dirs ==="
find /root/k70/uefi/Binaries/vermeer -maxdepth 4 -iname "*Iommu*" | head -20
echo "=== ClockProtocol unavailable string ==="
grep -rl "ClockProtocol unavailable" /root/k70/uefi/Binaries/vermeer 2>/dev/null | head -10
