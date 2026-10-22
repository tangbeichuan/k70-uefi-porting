#!/bin/bash
set -e
echo "=== notes mentioning keys85 / HALIOMMU outside script ==="
ls /mnt/d/本地项目-01/_tools/*.md 2>/dev/null | head -30
grep -rln "keys85\|HALIOMMU" /mnt/d/本地项目-01/_tools/*.md /mnt/d/本地项目-01/_tools/*.txt 2>/dev/null | head
echo "=== HALIOMMUDxe GUID table (.data + .text rodata) ==="
python3 - <<'PY'
import struct,subprocess
p='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi'
d=open(p,'rb').read()
out=subprocess.run(['llvm-readobj','--sections',p],capture_output=True,text=True).stdout
secs=[]; cur=None
for L in out.splitlines():
    L=L.strip()
    if L.startswith('Name:'):
        if cur: secs.append(cur)
        cur={'name':L.split(':',1)[1].strip()}
    elif cur is not None and ':' in L:
        k,v=L.split(':',1)
        if k in ('VirtualSize','VirtualAddress','RawDataSize','PointerToRawData'):
            try: cur[k]=int(v.split()[0],16)
            except: pass
if cur: secs.append(cur)
def gstr(b):
    a,bb,c=struct.unpack('<IHH',b[:8]); return '%08X-%04X-%04X-%s-%s'%(a,bb,c,b[8:10].hex().upper(),b[10:16].hex().upper())
seen=[]
for s in secs:
    if s.get('name') not in ('.data','.text'): continue
    base=s.get('VirtualAddress',0); raw=s.get('PointerToRawData',0); sz=s.get('RawDataSize',0)
    for off in range(0,sz-16,8):
        b=d[raw+off:raw+off+16]
        a1,bb,c=struct.unpack('<IHH',b[:8])
        if b[8:10]==b'\x00\x00' or b[10:16]==b'\x00'*6: continue
        if c==0: continue
        g=gstr(b)
        # dedupe, only plausible (version field small-ish)
        if c<=0x1000 and g not in seen:
            seen.append(g)
            print('  @0x%05x  %s'%(base+off,g))
PY
