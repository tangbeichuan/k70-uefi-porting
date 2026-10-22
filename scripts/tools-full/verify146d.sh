#!/bin/bash
# verify146d.sh -- confirm the UsbConfigDxe FFS inside the freshly built
# FVMAIN.Fv carries keys146's forced-fallback patch (RVA 0x3FA8 = 02 00 00 14)
# plus keys145's teardown guard (RVA 0x53CC = 28 01 00 B4).
set -u
FVF=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
UCFG=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
python3 - "$FVF" "$UCFG" <<'PY'
import sys, uuid
fv = open(sys.argv[1], 'rb').read()
pristine = open(sys.argv[2], 'rb').read()
print("FVMAIN.Fv = %d bytes" % len(fv))
print("pristine UsbConfigDxe.patched.efi = %d bytes" % len(pristine))
G = uuid.UUID('CD823A4D-7DEC-4531-AE5D-4134FA4127B8').bytes_le
hits = []
i = 0
while True:
    i = fv.find(G, i)
    if i < 0:
        break
    hits.append(i)
    i += 1
print("GUID hits:", [hex(x) for x in hits])
ok = True
for off in hits:
    size = int.from_bytes(fv[off + 0x14:off + 0x17], 'little')
    if not (0 < size < 0x40000):
        continue
    body = off + 0x18
    ffs = fv[body:body + size]
    mz = ffs.find(b'MZ')
    print("\nFFS guid@0x%x body=0x%x size=%d MZ@payload+0x%x" % (off, body, size, mz))
    if mz < 0:
        continue
    checks = [
        ("keys146 forced fallback", 0x3fa8, bytes.fromhex('02000014')),
        ("keys145 teardown guard ", 0x53cc, bytes.fromhex('280100b4')),
    ]
    for label, rva, want in checks:
        got = ffs[mz + rva:mz + rva + 4]
        same = got == want
        ok = ok and same
        print("  %-24s RVA 0x%x = %s %s" % (label, rva, got.hex(' '), "OK" if same else "MISMATCH expected " + want.hex(' ')))
    # run of keys146 condition: every byte of the 0x3FE8 success path must be untouched
    print("  0x3fa0-0x3fb8:", ffs[mz + 0x3fa0:mz + 0x3fb8].hex(' '))
    print("  0x53c4-0x53f0:", ffs[mz + 0x53c4:mz + 0x53f0].hex(' '))
    # sanity: only 2 differences vs pristine at the 8 patched bytes
    diff = [k for k in range(len(pristine)) if ffs[mz + k] != pristine[k]]
    print("  differences vs pristine efi payload:", [hex(x) for x in diff])
print("\nRESULT:", "OK" if ok else "FAILED")
PY
