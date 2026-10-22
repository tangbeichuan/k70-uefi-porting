#!/bin/bash
# verify144.sh -- keys144 (keys143b + ClockDxe restored before UsbConfigDxe)
set +e
TAG=keys144
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd
OUT=/mnt/d/本地项目-01/K70-UEFI-build
IMG=$OUT/Mu-vermeer-$TAG.img
COPY=$OUT/K70-keys144-CLOCKDXE.img
cp -f "$IMG" "$COPY"

echo "=== 1) deliverables ==="
sha256sum "$FD" "$IMG" "$COPY"
ls -l "$FD" "$IMG" "$COPY"

echo
echo "=== 2) Guid.xref: ClockDxe present + keys142 set + HALIOMMU absent + UFSDxe absent ==="
for p in ClockDxe AcpiTableDxe UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe UsbDeviceDxe VermeerPmicVerStubDxe PmicDxe VermeerDtbExtnDxe VermeerLogDiskDxe VermeerMenuDxe; do
  L=$(grep -i " $p\$" "$B/Guid.xref" | head -1)
  [ -z "$L" ] && L="---- $p"
  echo "  $L"
done
echo "  HALIOMMU : $(grep -ci 'HALIOMMU' "$B/Guid.xref") (expect 0)"
echo "  UFSDxe   : $(grep -ci 'UFSDxe' "$B/Guid.xref") (expect 0)"
echo "  4DB5DEA6 : $(grep -ci '4DB5DEA6' "$B/Guid.xref") (expect 1)"

echo
echo "=== 3) FVMAIN.inf placement (ClockDxe line vs UsbConfigDxe/UsbInitDxe/UsbMsdDxe) ==="
grep -n 'ClockDxe\|UsbConfigDxe\|UsbInitDxe\|UsbMsdDxe\|UsbfnDwc3Dxe\|AcpiTableDxe' "$B/FVMAIN.inf"

echo
echo "=== 4) FVMAIN.Fv bytes ==="
ls -l "$B/FVMAIN.Fv"
python3 - "$B/FVMAIN.Fv" <<'PY'
import sys,hashlib
fv=open(sys.argv[1],'rb').read()
def cnt(h): return fv.count(bytes.fromhex(h))
print('  ClockDxe FFS GUID 4DB5DEA6-5302-4D1A-8A82-677A683B0D29 :', cnt('a6deb54d024d1a4d8a82677a683b0d29'))
print('  gEfiClockProtocolGuid 241AFAE6-... occurrences        :', cnt('e6fa1a248f5f6c4fa7eac28eab79c3e5'))
print('  hardening patch 0802f836 (tbz w8,#0x1f)             :', cnt('0802f836'))
print('  HALIOMMU GUID 54B6D3B4 occurrences (expect 0)       :', cnt('b4d3b654335d914f86006c41d5deb19a'))
src=open('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb','rb').read()
print('  DTB xbl_ufs.dtb occurrences:', fv.count(src), ' sha256:', hashlib.sha256(src).hexdigest())
# UsbConfigDxe FFS: locate by GUID then check 0x3fa8 of its PE
import struct
g=bytes.fromhex('4d3a82cd7cdd3151ae5d4134fa4127b8')
i=0; found=0
while True:
    i=fv.find(g,i)
    if i<0: break
    found+=1; i+=1
print('  UsbConfigDxe FFS GUID occurrences:',found)
PY

echo
echo "=== 5) UsbConfigDxe FFS PE byte 0x3fa8 (expect 0802f836 in FV) ==="
python3 - "$B/FVMAIN.Fv" <<'PY'
import sys,re,os
fv=open(sys.argv[1],'rb').read()
files=re.findall(r'EFI_FILE_NAME = (\S+)',open('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.inf').read())
for f in files:
    if 'UsbConfigDxe' in f:
        b=open(f,'rb').read(); k=b.find(b'MZ')
        print('  %-60s %d B  PE@0x%x  0x3fa8=%s'%(os.path.basename(os.path.dirname(f)),len(b),k,b[k+0x3fa8:k+0x3fac].hex()))
    if 'ClockDxe' in f:
        b=open(f,'rb').read()
        print('  %-60s %d B  PE@0x%x'%(os.path.basename(os.path.dirname(f)),len(b),b.find(b'MZ')))
PY

echo
echo "=== 6) keys143b fallback untouched (path + sha) ==="
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/K70-keys143b-NO-HALIOMMU.img /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys143b.img 2>/dev/null
grep -n 'ClockDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/DXE.inc /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
