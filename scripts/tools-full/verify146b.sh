#!/bin/bash
# verify146b.sh -- locate UsbConfigDxe FFS in FVMAIN.Fv by its real FILE_GUID
# bytes (EFI_GUID mixed endian) and check the two patched u32 words.
set -u
FVF=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
python3 - "$FVF" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
print("FVMAIN.Fv size=%d" % len(d))
# CD823A4D-7DEC-4531-AE5D-4134FA4127B8  ->  EFI_GUID little endian bytes
g = bytes.fromhex('4d3a82cd' + '7dec' + '4531' + 'ae5d' + '4134fa4127b8')
print("target GUID bytes:", g.hex())
i, hits = 0, []
while True:
    i = d.find(g, i)
    if i < 0:
        break
    hits.append(i)
    i += 1
print("UsbConfigDxe GUID hits:", [hex(x) for x in hits])
for off in hits:
    hdr = off - 0x14
    if hdr < 0:
        continue
    sz = int.from_bytes(d[hdr + 0x14:hdr + 0x18], 'little') & 0xffffff
    body = hdr + 0x18
    print(" FFS hdr@0x%x guid@0x%x size=%d body=0x%x" % (hdr, off, sz, body))
    if not (0 < sz < 0x40000 and body + sz <= len(d)):
        continue
    ffs = d[body:body + sz]
    mz = ffs.find(b'MZ')
    print("   MZ@FFS+0x%x" % mz if mz >= 0 else "   no MZ")
    if mz < 0:
        continue
    for rva in (0x3fa8, 0x53cc, 0x53d0, 0x53d4, 0x53e0):
        cur = ffs[mz + rva:mz + rva + 4]
        print("   FFS+0x%x (RVA 0x%x) = %s" % (mz + rva, rva, cur.hex(' ')))
    print("   code 0x3fa0-0x3fb8:", ffs[mz + 0x3fa0:mz + 0x3fb8].hex(' '))
    print("   teardown 0x53c4-0x53f0:", ffs[mz + 0x53c4:mz + 0x53f0].hex(' '))
PY
