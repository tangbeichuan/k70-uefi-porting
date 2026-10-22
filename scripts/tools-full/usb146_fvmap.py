#!/usr/bin/env python3
"""usb146_fvmap.py -- map byte offsets in FVMAIN.Fv to FFS module names, then
report which module contains a string starting with 'transact'.

Also prints the GUIDs stored in UsbConfigDxe .data around 0x13000+0x1b8.
"""
import struct
import sys
import uuid

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def gstr(b, o):
    return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))


fv = open(FV, "rb").read()
print("FVMAIN.Fv", len(fv))
hdr = fv.find(b"_FVH", 0, 0x1000)
base = hdr - 0x28
print("FV base=0x%x len=0x%x" % (base, u64(fv, base + 0x20)))
off = base + u16(fv, base + 0x30)
mods = []
end = min(len(fv), base + u64(fv, base + 0x20))
while off + 0x18 <= end:
    ftype = fv[off + 0x12]
    size = fv[off + 0x14] | (fv[off + 0x15] << 8) | (fv[off + 0x16] << 16)
    if size < 0x18 or ftype == 0xFF:
        break
    guid = gstr(fv, off)
    body = off + 0x18
    name = None
    p = body
    b_end = off + size
    while p + 4 <= b_end:
        ssize = fv[p] | (fv[p + 1] << 8) | (fv[p + 2] << 16)
        stype = fv[p + 3]
        if ssize < 4:
            break
        if stype == 0x15:
            name = fv[p + 4: p + ssize].decode("utf-16-le", "ignore").rstrip("\x00")
            break
        p = (p + ssize + 3) & ~3
    mods.append((off, off + size, guid, name or guid))
    off = (off + size + 7) & ~7
print("modules:", len(mods))


def who(pos):
    for s, e, g, n in mods:
        if s <= pos < e:
            return "%s (%s) +0x%x" % (n, g, pos - s)
    return "FV header area"


pos = 0
hits = []
while True:
    pos = fv.find(b"transact", pos)
    if pos < 0:
        break
    hits.append(pos)
    pos += 1
print("\n'transact' hits and owning module:")
for h in hits:
    s = max(0, h - 8)
    ctx = fv[s:h + 40]
    printable = "".join(chr(c) if 32 <= c < 127 else "." for c in ctx)
    # is it the START of a C string?  check previous byte is NUL
    start_of_string = h == 0 or fv[h - 1] == 0
    print("  0x%-8x %s %r  start_of_string=%s" % (h, who(h), printable, start_of_string))

# UsbConfigDxe .data GUIDs (file copies under Binaries)
print("\nUsbConfigDxe data GUIDs 0x13190-0x13210:")
d = open("/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi", "rb").read()
for o in range(0x13190, 0x13210, 0x10):
    print("  0x%05x %s  %s" % (o, gstr(d, o), d[o:o + 16].hex()))
