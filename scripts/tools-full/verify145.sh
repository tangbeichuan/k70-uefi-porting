#!/bin/bash
# verify145.sh -- keys145 verification: HALIOMMU restored + UsbConfigDxe teardown
# NULL guard present + all earlier fixes still in place.
set -u
BUILD=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
FV=$BUILD/FV
FD=$FV/SILICIUM_UEFI-keys145.fd
XV=$FV/Guid.xref
IMG=/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys145.img
CP=/mnt/d/本地项目-01/K70-UEFI-build/K70-keys145-IOMMU-GUARD.img
DTB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
UCFG=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi

echo "===== artifacts ====="
for f in "$FD" "$IMG"; do
  if [ -f "$f" ]; then echo "OK   $f  $(stat -c %s "$f") B  sha256=$(sha256sum "$f" | cut -d' ' -f1)"; else echo "MISS $f"; fi
done
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/ | grep -i keys145

echo
echo "===== Guid.xref: keys145 must add HALIOMMU + keep ClockDxe/Usb*/Acpi/Pmic/DtbExtn ====="
for g in "9A00771F" "HALIOMMU" "4DB5DEA6" "ClockDxe" "CD823A4D" "UsbConfigDxe" "0A134F0E" "UsbInitDxe" "5AF77F10" "UsbMsdDxe" "94F8A6A7" "UsbfnDwc3Dxe" "3299A266" "UsbDeviceDxe" "3F6C1D92" "VermeerPmicVerStubDxe" "5776232E" "PmicDxe" "5B21E7C4" "VermeerDtbExtnDxe" "9C5E7A31" "VermeerLogDiskDxe" "4F7A1C2E" "VermeerMenuDxe" "9622E42C" "AcpiTableDxe"; do
  if grep -qi "$g" "$XV"; then echo "  OK   $g"; else echo "  MISS $g"; fi
done
echo "  UFSDxe (must be 0): $(grep -ci ufsdxe "$XV")"

echo
echo "===== FVMAIN.inf placement lines ====="
grep -n -i "HALIOMMU\|ClockDxe\|UsbConfigDxe\|UsbInitDxe\|UsbMsdDxe\|UsbfnDwc3Dxe\|AcpiTableDxe\|PmicDxe\|VermeerDtbExtnDxe\|VermeerPmicVerStub" "$FV/FVMAIN.inf" | head -30

echo
echo "===== FVMAIN.Fv: HALIOMMU GUID count + UsbConfigDxe hardened bytes ====="
FVF=$FV/FVMAIN.Fv
echo "FVMAIN.Fv size=$(stat -c %s $FVF)"
for pat in 1f77009a 9a00771f; do echo "  $pat count=$(xxd -p "$FVF" | tr -d '\n' | grep -o "$pat" | wc -l)"; done
# find UsbConfigDxe FFS via its own GUID, then check 0x3fa8 / 0x53cc inside that FFS
python3 - "$FVF" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
g=bytes.fromhex('4d3a82cd31e55dae5d4134fa4127b8')
i=0
found=[]
while True:
    i=d.find(g,i)
    if i<0: break
    found.append(i); i+=1
print("  UsbConfigDxe FFS GUID hits:", [hex(x) for x in found])
for off in found:
    hdr=off-0x14
    # FFS file header starts 0x14 before GUID; size at +0x14? GUID is inside header at off-0x10
    sz=int.from_bytes(d[hdr+0x14:hdr+0x18],'little') & 0xffffff
    body=hdr+0x18
    print("   FFS @0x%x size=%d body=0x%x" % (hdr,sz,body))
    if 0 < sz < 0x40000 and body+sz <= len(d):
        ffs=d[body:body+sz]
        for want,rva in ((bytes.fromhex('0802f836'),0x3fa8),(bytes.fromhex('280100b4'),0x53cc)):
            p=ffs.find(want)
            print("     want %s at FFS+%s (expect rva 0x%x)" % (want.hex(), hex(p) if p>=0 else 'MISS', rva))
PY

echo
echo "===== DTB in FV identical to source dtb ====="
echo "  src dtb sha256=$(sha256sum "$DTB" | cut -d' ' -f1)  size=$(stat -c %s "$DTB")"
python3 - "$FVF" "$DTB" <<'PY'
import sys
fv=open(sys.argv[1],'rb').read(); dtb=open(sys.argv[2],'rb').read()
n=fv.count(dtb)
print("  dtb occurrences in FVMAIN.Fv:", n, "size", len(dtb))
PY

echo
echo "===== UsbConfigDxe.patched.efi restored to pristine? ====="
xxd -s 0x3fa8 -l 8 "$UCFG"
xxd -s 0x53cc -l 16 "$UCFG"

echo
echo "===== HALIOMMU / ClockDxe efi present ====="
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/ 2>/dev/null | head -5
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ 2>/dev/null | head -5

echo
echo "===== copy image for flashing ====="
cp -f "$IMG" "$CP" && echo "copied -> $CP sha256=$(sha256sum "$CP" | cut -d' ' -f1)"
