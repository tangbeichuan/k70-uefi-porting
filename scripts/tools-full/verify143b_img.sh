#!/bin/bash
set +e
FB=/mnt/d/本地项目-01/K70-UEFI-build
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys143b.fd
IMG=$FB/Mu-vermeer-keys143b.img
COPY=$FB/K70-keys143b-NO-HALIOMMU.img
cp -f "$IMG" "$COPY"
echo "=== keys143b deliverables ==="
sha256sum "$FD"; sha256sum "$IMG"; sha256sum "$COPY"
ls -l "$FD" "$IMG" "$COPY"

echo
echo "=== xref: HALIOMMU must be ABSENT, keys142 set present ==="
for pat in HALIOMMU AcpiTableDxe UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe UsbDeviceDxe VermeerPmicVerStubDxe PmicDxe VermeerDtbExtnDxe VermeerLogDiskDxe VermeerMenuDxe; do
  line=$(grep -i "$pat" "/tmp/guid-keys143b.xref" 2>/dev/null | head -1)
  if [ -n "$line" ]; then echo "  OK   $line"; else echo "  ---- $pat"; fi
done

echo
echo "=== hardening patch inside FVMAIN.Fv (built for keys143b) ==="
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
ls -l "$FV"
python3 - "$FV" <<'PY'
import sys,glob,re,os
d=open(sys.argv[1],'rb').read()
print('  0x36F80208 hits:', d.count(bytes.fromhex('0802f836')))
files=re.findall(r'EFI_FILE_NAME = (\S+)',open('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.inf').read())
for f in files:
    if 'UsbConfigDxe' in f:
        b=open(f,'rb').read(); k=b.find(b'MZ')
        print('  UsbConfigDxe ffs:',os.path.basename(os.path.dirname(f)),len(b),'B  PE@0x%x  0x3fa8=%s'%(k,b[k+0x3fa8:k+0x3fac].hex()))
PY

echo
echo "=== DTB payload ==="
python3 - "$FV" <<'PY'
import sys,hashlib
fv=open(sys.argv[1],'rb').read()
src=open('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb','rb').read()
print('  xbl_ufs.dtb occurrences:',fv.count(src),'sha256:',hashlib.sha256(src).hexdigest())
PY
