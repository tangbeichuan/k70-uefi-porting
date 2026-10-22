#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi
echo "=== sections ==="
llvm-readobj --sections "$F" | grep -E "Name:|VirtualSize|VirtualAddress|RawDataSize|PointerToRawData"
echo "=== strings: iommu/smmu/scm/dt ==="
strings -t x "$F" | grep -iE "iommu|smmu|scm|dtb|device ?tree|clock|rpmh|dalsys|shmbridge" | head -40
echo "=== GUID table candidates in .data ==="
python3 - "$F" <<'PY'
import struct,sys,re
d=open(sys.argv[1],'rb').read()
import subprocess
out=subprocess.run(['llvm-readobj','--sections',sys.argv[1]],capture_output=True,text=True).stdout
# find .data range
va=raw=size=None
lines=out.splitlines()
name=None
for i,L in enumerate(lines):
    if 'Name:' in L: cur=L
    if 'VirtualAddress:' in L: va=int(L.split(':')[1].strip(),16)
    if 'PointerToRawData:' in L: raw=int(L.split(':')[1].strip(),16)
    if 'RawDataSize:' in L: size=int(L.split(':')[1].strip(),16)
    if cur and '.data' in cur and va is not None and raw is not None and size is not None:
        pass
    # crude: detect when new section starts
    if 'Name:' in L:
        if 'cur_va' in dir(): pass
PY
python3 - "$F" <<'PY'
import struct,sys,subprocess,re
p=sys.argv[1]; d=open(p,'rb').read()
out=subprocess.run(['llvm-readobj','--sections',p],capture_output=True,text=True).stdout
secs=[]; cur={}
for L in out.splitlines():
    L=L.strip()
    if L.startswith('Name:'): 
        if cur: secs.append(cur)
        cur={'name':L.split(':',1)[1].strip()}
    elif ':' in L:
        k,v=L.split(':',1)
        if k in ('VirtualSize','VirtualAddress','RawDataSize','PointerToRawData'):
            try: cur[k]=int(v.split()[0],16)
            except: pass
if cur: secs.append(cur)
for s in secs: print(' section',s)
data=[s for s in secs if s.get('name')=='.data'][0]
base=data.get('VirtualAddress',0); raw=data.get('PointerToRawData',0); sz=data.get('RawDataSize',0)
def gstr(b):
    a,bb,c=struct.unpack('<IHH',b[:8]); return '%08X-%04X-%04X-%s-%s'%(a,bb,c,b[8:10].hex().upper(),b[10:16].hex().upper())
print(' .data va=%x size=%x'%(base,sz))
for off in range(0,sz-16,4):
    b=d[raw+off:raw+off+16]
    a1,bb,c=struct.unpack('<IHH',b[:8])
    if b[8:16].count(0)==8: continue
    # heuristic: version field c in 0x0000-0xffff and something nonzero
    if c in (0,): continue
    print('  @0x%05x  %s'%(base+off,gstr(b)))
PY
