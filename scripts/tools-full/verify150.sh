#!/bin/bash
# verify keys150 artifacts + FV content
TAG=keys150
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-${TAG}.fd
IMG=/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-${TAG}.img
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
XREF=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref
FVI=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.inf
echo "===== artifacts ====="
ls -l "$FD" "$IMG" 2>/dev/null
sha256sum "$FD" "$IMG" 2>/dev/null
echo "===== Guid.xref (keys142+ set) ====="
for g in AcpiTableDxe UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe UsbDeviceDxe VermeerPmicVerStubDxe PmicDxe VermeerDtbExtnDxe VermeerLogDiskDxe VermeerMenuDxe ClockDxe HALIOMMU UFSDxe; do
  n=$(grep -c "$g" "$XREF" 2>/dev/null)
  echo "$g=$n"
done
echo "===== FVMAIN.inf placement ====="
grep -n 'UsbfnDwc3\|UsbMsd\|UsbConfig\|UsbInit\|UsbDevice\|ClockDxe\|HALIOMMU\|AcpiTable\|VermeerMenu\|VermeerDtbExtn' "$FVI" 2>/dev/null | head -20
echo "===== FVMAIN.Fv ====="
ls -l "$FV"
python3 - "$FV" <<'PY'
import sys
b=open(sys.argv[1],'rb').read()
print('FVMAIN.Fv size', len(b))
for pat in ('USB150','MENU150','GSNPSID=','gsts_b0','GCC_GDSCR','[VBUS]','USB149'):
    print('  %-12s utf16=%d ascii=%d' % (pat, b.count(pat.encode('utf-16-le')), b.count(pat.encode('ascii'))))
PY
echo "===== UsbConfigDxe FFS patches (via cf146d.py) ====="
python3 /mnt/d/本地项目-01/_tools/cf146d.py "$FD" 2>/dev/null | grep -i -E 'UsbConfigDxe|HALIOMMU|ClockDxe' | head -10
echo "===== DTB inside FV ====="
python3 - <<'PY'
import hashlib
fv=open('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv','rb').read()
blob=open('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/xbl_ufs.dtb','rb').read() if __import__('os').path.exists('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/xbl_ufs.dtb') else None
src=open('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb','rb').read()
print('src dtb len', len(src), 'sha', hashlib.sha256(src).hexdigest()[:16])
print('occurrences in FV:', fv.count(src))
PY
echo "===== menu efi ====="
M=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
ls -l "$M" 2>/dev/null
strings "$M" 2>/dev/null | grep -c 'USB150'
