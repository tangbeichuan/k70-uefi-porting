#!/usr/bin/env bash
set +e
TAG=keys142
BV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
FVD=$BV/FV
IMG=/mnt/d/本地项目-01/K70-UEFI-build
OUT=$IMG/K70-keys142-ACPI-SDT.img

echo "=== 1) Guid.xref: AcpiTableDxe + UsbConfig/UsbInit/UsbMsd/UsbfnDwc3/PmicVerStub + keys140 kept ==="
for n in AcpiTableDxe UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe VermeerPmicVerStubDxe PmicDxe VermeerDtbExtnDxe VermeerLogDiskDxe VermeerMenuDxe; do
  printf '%-24s ' "$n"
  grep -i " $n\$" $FVD/Guid.xref | head -1
  echo
done

echo "=== 2) FVMAIN.inf placement lines ==="
grep -n -i "AcpiTableDxe\|UsbConfigDxe\|UsbInitDxe\|UsbMsdDxe\|UsbfnDwc3Dxe\|PmicVerStubDxe" $FVD/FVMAIN.inf

echo "=== 3) FVMAIN.Fv GUID presence (AcpiTableDxe FFS + SDT producer protocol) ==="
python3 - <<'PY'
import struct
data = open("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv","rb").read()
def gb(s):
    q=s.split('-')
    return struct.pack('<IHH',int(q[0],16),int(q[1],16),int(q[2],16))+bytes.fromhex(q[3]+q[4])
for name,g in [("FILE:AcpiTableDxe","9622E42C-8E38-4A08-9E8F-54F784652F6B"),
               ("proto:AcpiSdt EB97088E","EB97088E-CFDF-49C6-BE4B-D906A5B20E86"),
               ("proto:AcpiTable FFE06BDD","FFE06BDD-6107-46A6-7BB2-5A9C7EC5275C"),
               ("FILE:UsbConfigDxe","CD823A4D-7DEC-4531-AE5D-4134FA4127B8"),
               ("FILE:VermeerPmicVerStubDxe","3F6C1D92-85B4-4E27-9C63-1A8F5D2E7B04")]:
    pat=gb(g); off=0; hits=[]
    while True:
        i=data.find(pat,off)
        if i<0: break
        hits.append("0x%x"%i); off=i+1
    print("  %-26s count=%d %s" % (name,len(hits),hits[:5]))
PY

echo "=== 4) DTB blob still identical + provider strings ==="
python3 - <<'PY'
import hashlib
dtb = open("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb","rb").read()
fv = open("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv","rb").read()
print("  source dtb sha256:", hashlib.sha256(dtb).hexdigest(), "size", len(dtb), "copies in FV:", fv.count(dtb))
PY
for s in "vermeer dtb-extn provider" "+0x28 count(" "+0x68 sizes(" "+0x70 names(" "selftest vadc"; do
  printf '  %-30s %s\n' "$s" "$(grep -c -a -F "$s" $FVD/FVMAIN.Fv)"
done

echo "=== 5) AcpiTableDxe.efi built ==="
ls -l $BV/AARCH64/AcpiTableDxe.efi

echo "=== 6) copy + sha256 of deliverables ==="
cp -f "$IMG/Mu-vermeer-$TAG-fat.img" "$OUT" 2>/dev/null || cp -f "$IMG/Mu-vermeer-$TAG.img" "$OUT"
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$IMG/Mu-vermeer-$TAG.img" "$OUT"
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$IMG/Mu-vermeer-$TAG.img" "$OUT"

echo "=== 7) sanity: no UFSDxe in FVMAIN.inf ==="
grep -c -i "UFSDxe" $FVD/FVMAIN.inf
