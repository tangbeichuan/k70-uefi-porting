#!/bin/bash
set +e
FVD=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
python3 - "$FVD/FVMAIN.Fv" <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read()
# enumerate FFS files: shift through FV to find FFS2 signatures
def find_ffs_files(d):
    res=[]
    i=0
    while True:
        j=d.find(b'\xAA\x64\x3B\x8C',i)  # not reliable; do GUID-based below
        break
    return res
# Simpler: use FVMAIN.inf list of ffs files
import re,os
inf=open('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.inf').read()
files=re.findall(r'EFI_FILE_NAME = (\S+)',inf)
patched=bytes.fromhex('0802f836')
orig=bytes.fromhex('0802f8b6')
# search for original instruction and patched occurrence, then map to nearest preceding ffs content in FV
def locate(pos):
    best=None
    for f in files:
        try: b=open(f,'rb').read()
        except Exception: continue
        k=d.find(b)
        if k>=0 and k<=pos and (best is None or k>best[1]):
            best=(f,k)
    return best
for name,pat in (('PATCHED',patched),('ORIGINAL',orig)):
    i=d.find(pat)
    while i>=0:
        b=locate(i)
        mod=os.path.basename(os.path.dirname(b[0])) if b else '?'
        print('%s hit @0x%x  in %s (+0x%x)'%(name,i,mod,i-(b[1] if b else 0)))
        i=d.find(pat,i+1)
# exact check of UsbConfigDxe ffs
for f in files:
    if 'UsbConfigDxe' in f:
        b=open(f,'rb').read()
        print('\nUsbConfigDxe ffs size',len(b))
        # FFS header 0x18, section header, then PE
        k=b.find(b'MZ')
        print('MZ at ffs offset 0x%x'%k)
        for off in (0x3fa4,0x3fa8):
            print('  ffs byte 0x%x: %s'%(k+off, b[k+off:k+off+4].hex()))
PY
