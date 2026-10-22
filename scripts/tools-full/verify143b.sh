#!/bin/bash
set +e
FVD=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
FV=$FVD/FVMAIN.Fv
echo "=== FVMAIN.Fv size ==="; ls -l "$FV"
python3 - "$FV" <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read()
def g(s):
    parts=s.split('-')
    a,b,c=parts[0],parts[1],parts[2]
    rest=''.join(parts[3:])
    return struct.pack('<IHH',int(a,16),int(b,16),int(c,16))+bytes.fromhex(rest)
guids={
 'HALIOMMUDxe(9A00771F)': g('9A00771F-36D4-4DD5-8916-C48ED9B16B86'),
 'AcpiTableDxe(9622E42C)': g('9622E42C-8E38-4A08-9E8F-54F784652F6B'),
 'UsbConfigDxe(CD823A4D)': g('CD823A4D-7DEC-4531-AE5D-4134FA4127B8'),
 'VermeerDtbExtnDxe(5B21E7C4)': g('5B21E7C4-3D18-4F6A-9A20-8C7E51FD42B9'),
 'PmicDxe(5776232E)': g('5776232E-082D-4B75-9A0E-FE1D13F7A5D9'),
 'VermeerPmicVerStub(3F6C1D92)': g('3F6C1D92-85B4-4E27-9C63-1A8F5D2E7B04'),
}
for name,pat in guids.items():
    offs=[]; i=d.find(pat)
    while i>=0 and len(offs)<6:
        offs.append('0x%x'%i); i=d.find(pat,i+1)
    print('  %-32s count=%d %s'%(name,len(offs),' '.join(offs)))
patched=bytes.fromhex('0802f836')
orig=bytes.fromhex('0802f8b6')
print('  hardening patch 0x36F80208 (tbz w8,#0x1f): %d hit(s)'%d.count(patched))
print('  original 0xB6F80208 (tbz x8,#0x3f)      : %d hit(s)'%d.count(orig))
# locate UsbConfigDxe FFS body and check the patch inside it
fid=g('CD823A4D-7DEC-4531-AE5D-4134FA4127B8')
base=d.find(fid)
while base>=0:
    # FFS file header: 16 guid + 8 rest => body starts +0x18, section header +0x18+0x04...
    body=d[base:base+0x9000]
    if body.count(bytes.fromhex('0802f836')) and body.count(bytes.fromhex('0802f8b6'))==0:
        print('  UsbConfigDxe FFS @0x%x: patched instruction PRESENT (offset in ffs 0x%x)'%(base, base+body.find(bytes.fromhex('0802f836'))-base))
        break
    base=d.find(fid,base+1)
PY
echo
echo "=== HALIOMMU FFS / DTBDxe FFS heads ==="
python3 - "$FVD" <<'PY'
import sys,glob,hashlib
for pat in ('*HALIOMMU*/*.ffs','*VermeerDtbExtnDxe*/*.ffs','*UsbConfigDxe*/*.ffs'):
    for f in glob.glob(sys.argv[1]+'/Ffs/'+pat):
        b=open(f,'rb').read()
        print('  %-90s %d B sha256=%s'%(f.split('/Ffs/')[-1],len(b),hashlib.sha256(b).hexdigest()[:16]))
PY
