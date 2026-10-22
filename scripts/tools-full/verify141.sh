#!/usr/bin/env bash
set +e
BV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
FVD=$BV/FV
IMG=/mnt/d/本地项目-01/K70-UEFI-build
OUT=$IMG/K70-keys141-USB-CONFIG.img

echo "=== 1) Guid.xref: 5 required modules + kept keys140 modules ==="
for n in UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe VermeerPmicVerStubDxe PmicDxe VermeerDtbExtnDxe VermeerLogDiskDxe VermeerMenuDxe; do
  printf '%-24s ' "$n"
  grep -i " $n\$" $FVD/Guid.xref | head -1 || true
  echo
done

echo "=== 2) FVMAIN.inf placement lines ==="
grep -n -i "UsbConfigDxe\|UsbInitDxe\|UsbMsdDxe\|UsbfnDwc3Dxe\|PmicVerStubDxe" $FVD/FVMAIN.inf

echo "=== 3) UsbConfigDxe FFS in FVMAIN.Fv ==="
python3 - <<'PY'
import struct
data = open("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv","rb").read()
def gb(s):
    q=s.split('-')
    return struct.pack('<IHH',int(q[0],16),int(q[1],16),int(q[2],16))+bytes.fromhex(q[3]+q[4])
for name,g in [("FILE:UsbConfigDxe","CD823A4D-7DEC-4531-AE5D-4134FA4127B8"),
               ("depex:EB97088E","EB97088E-CFDF-49C6-BE4B-D906A5B20E86"),
               ("FILE:VermeerPmicVerStubDxe","3F6C1D92-85B4-4E27-9C63-1A8F5D2E7B04"),
               ("proto:PmicVersion","4684800A-2755-4EDC-B443-7F8CEB3239D3")]:
    pat=gb(g); off=0; hits=[]
    while True:
        i=data.find(pat,off)
        if i<0: break
        hits.append("0x%x"%i); off=i+1
    print("  %-26s %-38s count=%d %s" % (name,g,len(hits),hits[:4]))
PY

echo "=== 4) DTB blob still identical to xbl_ufs.dtb ==="
python3 - <<'PY'
import struct, hashlib
dtb = open("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb","rb").read()
fv = open("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv","rb").read()
print("  source dtb sha256:", hashlib.sha256(dtb).hexdigest(), "size", len(dtb))
print("  found in FV:", fv.count(dtb), "byte-identical copy")
PY

echo "=== 5) provider banner + strings in FVMAIN.Fv ==="
for s in "vermeer dtb-extn provider" "+0x28 count(" "+0x68 sizes(" "+0x70 names(" "selftest vadc"; do
  printf '  %-30s %s\n' "$s" "$(grep -c -a -F "$s" $FVD/FVMAIN.Fv)"
done

echo "=== 6) depex of module inside FV (UsbConfigDxe.depex bytes) ==="
xxd -p /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.depex | tr -d '\n'; echo

echo "=== 7) copy + sha256 of deliverables ==="
cp -f /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys141-fat.img "$OUT" 2>/dev/null || \
  cp -f /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys141.img "$OUT"
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys141.fd \
      /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys141.img "$OUT"
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys141.fd \
      /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys141.img "$OUT"

echo "=== 8) sanity: no UFSDxe, LogDisk before menu in APRIORI (build-time already checked) ==="
grep -c -i "UFSDxe" $FVD/FVMAIN.inf
