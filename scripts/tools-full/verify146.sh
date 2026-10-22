#!/bin/bash
# verify146.sh -- keys146 verification.
# keys146 = keys145 lineage (HALIOMMU + ClockDxe + teardown guard) + the real
# EFI_ERROR fix at UsbConfigDxe 0x3FA8 (b 0x3FB0 => vendor no-IOMMU branch).
set -u
BUILD=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
FV=$BUILD/FV
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys146.fd
XV=$FV/Guid.xref
IMGV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerLogDiskDxe.efi
IMG=/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys146.img
CP=/mnt/d/本地项目-01/K70-UEFI-build/K70-keys146-NO-IOMMU-INIT.img
DTB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
UCFG=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
FVF=$FV/FVMAIN.Fv

echo "===== artifacts ====="
for f in "$FD" "$IMG"; do
  if [ -f "$f" ]; then echo "OK   $f  $(stat -c %s "$f") B  sha256=$(sha256sum "$f" | cut -d' ' -f1)"; else echo "MISS $f"; fi
done
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/ | grep -i keys146
ls -l /mnt/d/本地项目-01/K70-UEFI-build/ | grep -i "keys146\|keys145"

echo
echo "===== Guid.xref: keys145 set must still be there (no UFSDxe) ====="
for g in "9A00771F" "HALIOMMU" "4DB5DEA6" "ClockDxe" "CD823A4D" "UsbConfigDxe" "0A134F0E" "UsbInitDxe" "5AF77F10" "UsbMsdDxe" "94F8A6A7" "UsbfnDwc3Dxe" "3299A266" "UsbDeviceDxe" "3F6C1D92" "VermeerPmicVerStubDxe" "5776232E" "PmicDxe" "5B21E7C4" "VermeerDtbExtnDxe" "9C5E7A31" "VermeerLogDiskDxe" "4F7A1C2E" "VermeerMenuDxe" "9622E42C" "AcpiTableDxe"; do
  if grep -qi "$g" "$XV"; then echo "  OK   $g"; else echo "  MISS $g"; fi
done
echo "  UFSDxe (must be 0): $(grep -ci ufsdxe "$XV")"

echo
echo "===== FVMAIN.inf placement lines ====="
grep -n -i "HALIOMMU\|ClockDxe\|UsbConfigDxe\|UsbInitDxe\|UsbMsdDxe\|UsbfnDwc3Dxe\|AcpiTableDxe\|PmicDxe\|VermeerDtbExtnDxe\|VermeerPmicVerStub" "$FV/FVMAIN.inf" | head -30

echo
echo "===== FVMAIN.Fv: UsbConfigDxe patch bytes (3fa8=02000014, 53cc=280100b4) ====="
echo "FVMAIN.Fv size=$(stat -c %s $FVF)"
python3 - "$FVF" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
g = bytes.fromhex('4d3a82cd31e55dae5d4134fa4127b8')   # UsbConfigDxe FFS FILE_GUID
i, hits = 0, []
while True:
    i = d.find(g, i)
    if i < 0:
        break
    hits.append(i)
    i += 1
print("  UsbConfigDxe FFS GUID hits:", [hex(x) for x in hits])
for off in hits:
    hdr = off - 0x14
    sz = int.from_bytes(d[hdr + 0x14:hdr + 0x18], 'little') & 0xffffff
    body = hdr + 0x18
    if not (0 < sz < 0x40000 and body + sz <= len(d)):
        continue
    ffs = d[body:body + sz]
    mz = ffs.find(b'MZ')
    print("   FFS @0x%x size=%d MZ@FFS+0x%x" % (hdr, sz, mz))
    for want, rva in ((bytes.fromhex('02000014'), 0x3fa8),
                      (bytes.fromhex('280100b4'), 0x53cc),
                      (bytes.fromhex('080540f9'), 0x53d0)):
        p = ffs.find(want, mz + rva if mz >= 0 else 0)
        ok = (p == mz + rva)
        print("     %s at FFS+0x%x (expect FFS+0x%x) %s"
              % (want.hex(), p, mz + rva, "OK" if ok else "MISMATCH"))
    print("     full: %s" % ffs[mz + 0x3fa0:mz + 0x3fb8].hex(" "))
    print("     teardown: %s" % ffs[mz + 0x53c4:mz + 0x53f0].hex(" "))
PY

echo
echo "===== DTB in FV identical to source dtb ====="
echo "  src dtb sha256=$(sha256sum "$DTB" | cut -d' ' -f1)  size=$(stat -c %s "$DTB")"
python3 - "$FVF" "$DTB" <<'PY'
import sys
fv = open(sys.argv[1], 'rb').read()
dtb = open(sys.argv[2], 'rb').read()
print("  dtb occurrences in FVMAIN.Fv:", fv.count(dtb), "size", len(dtb))
PY

echo
echo "===== UsbConfigDxe.patched.efi restored to pristine? (b6f80208 / 080540f9) ====="
xxd -s 0x3fa8 -l 8 "$UCFG"
xxd -s 0x53cc -l 16 "$UCFG"

echo
echo "===== copy image for flashing ====="
cp -f "$IMG" "$CP" && echo "copied -> $CP sha256=$(sha256sum "$CP" | cut -d' ' -f1)"
