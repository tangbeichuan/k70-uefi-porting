#!/bin/bash
# verify145c.sh -- prove the UsbConfigDxe FFS inside FVMAIN.Fv carries the
# keys145 binary patches (not a coincidence match).
set -u
FVF=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
UCFG=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
python3 - "$FVF" "$UCFG" <<'PY'
import sys, uuid
fv=open(sys.argv[1],'rb').read()
efi=open(sys.argv[2],'rb').read()
print("pristine efi size =", len(efi), hex(len(efi)))
G=uuid.UUID('CD823A4D-7DEC-4531-AE5D-4134FA4127B8').bytes_le
hits=[]; i=0
while True:
    i=fv.find(G,i)
    if i<0: break
    hits.append(i); i+=1
for off in hits:
    size=int.from_bytes(fv[off+0x14:off+0x17],'little')
    if 0 < size < 0x40000:
        body=off+0x18
        ffs=fv[body:body+size]
        print("FFS @0x%x body=0x%x size=%d" % (off, body, size))
        # compare FFS payload with the pristine efi byte-for-byte where they overlap
        n=min(len(ffs), len(efi))
        same=sum(1 for k in range(n) if ffs[k]==efi[k])
        print("  payload-vs-pristine equal bytes: %d/%d (%.1f%%)" % (same, n, 100.0*same/n))
        # locate MZ inside payload
        mz=ffs.find(b'MZ')
        print("  MZ at payload+0x%x" % mz)
        for name, pat in (
            ("patched 0x3fa8 (f8360208)", bytes.fromhex('0802f836')),
            ("pristine 0x3fa8 (b6f80208)", bytes.fromhex('0802f8b6')),
            ("patched 0x53cc (cbz)", bytes.fromhex('280100b4080540f9690000d0')),
            ("pristine 0x53cc (no guard)", bytes.fromhex('080540f9690000d0e90300f9')),
        ):
            p=ffs.find(pat)
            print("  %-32s first at payload+%s" % (name, hex(p) if p>=0 else 'MISS'))
        # map expected file offsets: efi file offset == rva; payload holds PE at mz
        for rva in (0x3fa8, 0x53cc, 0x53d0, 0x53d4, 0x53e0):
            fo=mz+rva
            print("   rva 0x%x -> payload+0x%x bytes %s" % (rva, fo, ffs[fo:fo+4].hex()))
        # also show pristine efi bytes at same rvas for comparison
        print("   pristine efi @0x3fa8=%s @0x53cc=%s" % (efi[0x3fa8:0x3fac].hex(), efi[0x53cc:0x53d0].hex()))
PY
