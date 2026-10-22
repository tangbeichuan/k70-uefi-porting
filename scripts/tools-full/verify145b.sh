#!/bin/bash
# verify145b.sh -- fix-ups: FD lives in _k70port_extract/qemu-fw; check the
# UsbConfigDxe FFS inside FVMAIN.Fv with correct GUID byte order.
set -u
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd
FVF=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
IMG=/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys145.img

echo "===== FD ====="
stat -c '%s B  %y' "$FD"
sha256sum "$FD"

echo
echo "===== FVMAIN.Fv in-FV byte checks ====="
python3 - "$FVF" <<'PY'
import sys
fv=open(sys.argv[1],'rb').read()
print("FVMAIN.Fv size =", len(fv))
def guid(s):
    import uuid
    return uuid.UUID(s).bytes_le
G_USBCFG=guid('CD823A4D-7DEC-4531-AE5D-4134FA4127B8')
G_HAL   =guid('9A00771F-36D4-4DD5-8916-C48ED9B16B86')
G_CLK   =guid('4DB5DEA6-5302-4D1A-8A82-677A683B0D29')
print("HALIOMMU GUID occurrences:", fv.count(G_HAL))
print("ClockDxe GUID occurrences:", fv.count(G_CLK))
hits=[]
i=0
while True:
    i=fv.find(G_USBCFG,i)
    if i<0: break
    hits.append(i); i+=1
print("UsbConfigDxe GUID hits:", [hex(h) for h in hits])
for off in hits:
    hdr=off-0x10          # FFS header: 16B name + 4B integrity? => GUID at hdr+0x10
    # EFI_FFS_FILE_HEADER: Name(16) IntegrityCheck(2) Type(1) Attributes(1)
    #                      Size(3) State(1) => GUID at hdr..hdr+15, header size 0x18
    start=off
    size=int.from_bytes(fv[start+0x14:start+0x17],'little')
    body=start+0x18
    print("  FFS GUID@0x%x size=%d body=0x%x" % (start,size,body))
    if 0<size<0x40000 and body+size<=len(fv):
        ffs=fv[body:body+size]
        for want,rva,name in ((bytes.fromhex('0802f836'),0x3fa8,'EFI_ERROR via tbz w8,#0x1f'),
                              (bytes.fromhex('280100b4'),0x53cc,'NULL guard cbz x8,0x53f0'),
                              (bytes.fromhex('690000d0'),0x53d4,'adrp x9,0x13000')):
            p=ffs.find(want)
            print("     %-30s at FFS+%s  (expect rva 0x%x)" % (name, hex(p) if p>=0 else 'MISS', rva))
PY

echo
echo "===== DTB identical ====="
DTB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
python3 - "$FVF" "$DTB" <<'PY'
import sys
fv=open(sys.argv[1],'rb').read(); dtb=open(sys.argv[2],'rb').read()
print("  dtb occurrences:", fv.count(dtb), "size", len(dtb))
PY

echo
echo "===== summary shas ====="
sha256sum "$FD" "$IMG" /mnt/d/本地项目-01/K70-UEFI-build/K70-keys145-IOMMU-GUARD.img
