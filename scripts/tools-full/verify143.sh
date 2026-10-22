#!/bin/bash
# verify keys143: HALIOMMU back in FV, UsbConfigDxe hardening patch embedded,
#                  keys140/141/142 achievements still present.
set +e
TAG=${1:-keys143}
UEFI=/root/k70/uefi
FB=/mnt/d/本地项目-01/K70-UEFI-build
FVD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd
IMG=$FB/Mu-vermeer-$TAG.img
COPY=$FB/K70-keys143-USB-CONFIG-2.img

echo "=== [1] sha256 ==="
sha256sum "$FD" 2>/dev/null
sha256sum "$IMG" 2>/dev/null
cp -f "$IMG" "$COPY" && sha256sum "$COPY"
ls -l "$FD" "$IMG" "$COPY" 2>/dev/null

echo
echo "=== [2] Guid.xref: HALIOMMU + keys14x modules ==="
for pat in HALIOMMU AcpiTableDxe UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe VermeerPmicVerStubDxe PmicDxe VermeerDtbExtnDxe VermeerLogDiskDxe VermeerMenuDxe UFSDxe; do
  line=$(grep -i " $pat\$" "/tmp/guid-$TAG.xref" 2>/dev/null | head -1)
  if [ -z "$line" ]; then
    line=$(grep -i "$pat" "/tmp/guid-$TAG.xref" 2>/dev/null | head -1)
  fi
  if [ -n "$line" ]; then echo "  OK   $line"; else echo "  MISS $pat"; fi
done

echo
echo "=== [3] FVMAIN.inf placement lines ==="
grep -n "HALIOMMUDxe\|AcpiTableDxe\|UsbConfigDxe\|UsbInitDxe\|UsbMsdDxe\|UsbfnDwc3Dxe\|VermeerPmicVerStubDxe" "$FVD/FVMAIN.inf" | head -20

echo
echo "=== [4] FVMAIN.Fv raw GUID/bytes ==="
FV=$FVD/FVMAIN.Fv
ls -l "$FV"
python3 - "$FV" <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read()
def g(s):
    a,b,c,rest=s.split('-'); 
    return struct.pack('<IHH',int(a,16),int(b,16),int(c,16))+bytes.fromhex(rest.replace('-',''))
guids={
 'HALIOMMUDxe(9A00771F)': g('9A00771F-36D4-4DD5-8916-C48ED9B16B86'),
 'AcpiTableDxe(9622E42C)': g('9622E42C-8E38-4A08-9E8F-54F784652F6B'),
 'UsbConfigDxe(CD823A4D)': g('CD823A4D-7DEC-4531-AE5D-4134FA4127B8'),
 'VermeerDtbExtnDxe(5B21E7C4)': g('5B21E7C4-3D18-4F6A-9A20-8C7E51FD42B9'),
 'PmicDxe(5776232E)': g('5776232E-082D-4B75-9A0E-FE1D13F7A5D9'),
}
for name,pat in guids.items():
    offs=[]; i=d.find(pat)
    while i>=0 and len(offs)<6:
        offs.append(hex(i)); i=d.find(pat,i+1)
    print('  %-32s count=%d %s'%(name,len(offs),' '.join(offs)))
patched=bytes.fromhex('0802f836')   # tbz w8,#0x1f
orig=bytes.fromhex('0802f8b6')      # tbz x8,#0x3f
print('  UsbConfigDxe hardening patch 0x36F80208 : %d hit(s)'%d.count(patched))
print('  original 0xB6F80208 (should be 0 if fully patched): %d hit(s)'%d.count(orig))
PY

echo
echo "=== [5] DTB payload still identical to xbl_ufs.dtb ==="
python3 - "$FV" <<'PY'
import sys,hashlib
fv=open(sys.argv[1],'rb').read()
src=open('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb','rb').read()
n=fv.count(src)
print('  xbl_ufs.dtb size=%d sha256=%s  occurrences_in_FV=%d'%(len(src),hashlib.sha256(src).hexdigest(),n))
PY

echo
echo "=== [6] provider assertion strings in FVMAIN.Fv ==="
for s in "vermeer dtb-extn provider" "+0x28 count(" "+0x68 sizes(" "+0x70 names(" "selftest vadc"; do
  c=$(grep -a -c -- "$s" "$FV" 2>/dev/null)
  echo "  \"$s\" : $c"
done
echo
echo "=== [7] APRIORI order inside built FVMAIN (FFS GUIDs, first 40) ==="
python3 - "$FVD" <<'PY'
import sys,re
try:
    txt=open(sys.argv[1]+'/FVMAIN.inf').read()
except Exception as e:
    print(e); raise SystemExit
mods=re.findall(r'^EFI_FILE_NAME = (\S+)',txt,re.M)
print('  FVMAIN.inf module count:',len(mods))
print('  first 30:',', '.join(mods[:30]))
PY
