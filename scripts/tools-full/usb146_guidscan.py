#!/usr/bin/env python3
"""usb146_guidscan.py -- find every FVMAIN module (and Binaries driver) whose
bytes contain GUID 54B6D3B4-5D33-4F91-8600-6C41D5DEB19A, plus the same for
E722B03F and 0389B776, and map offsets inside FVMAIN to module names."""
import os
import struct
import uuid

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
BIN = "/root/k70/uefi/Binaries/vermeer"

GUIDS = {
    "HAL_IOMMU 54B6D3B4": bytes.fromhex("b4d3b654335d914f86006c41d5deb19a"),
    "E722B03F": bytes.fromhex("3fb022e750b2ce428ebd5bd51812d037"),
    "DTBEXTN 0389B776": bytes.fromhex("76b789035f62eb1183bec741a913de34"),
}


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


fv = open(FV, "rb").read()
hdr = fv.find(b"_FVH", 0, 0x1000)
base = hdr - 0x28
off = base + u16(fv, base + 0x30)
end = min(len(fv), base + u64(fv, base + 0x20))
mods = []
while off + 0x18 <= end:
    ftype = fv[off + 0x12]
    size = fv[off + 0x14] | (fv[off + 0x15] << 8) | (fv[off + 0x16] << 16)
    if size < 0x18 or ftype == 0xFF:
        break
    guid = str(uuid.UUID(bytes_le=bytes(fv[off:off + 16])))
    body = off + 0x18
    name = None
    p = body
    while p + 4 <= off + size:
        ss = fv[p] | (fv[p + 1] << 8) | (fv[p + 2] << 16)
        st = fv[p + 3]
        if ss < 4:
            break
        if st == 0x15:
            name = fv[p + 4:p + ss].decode("utf-16-le", "ignore").rstrip("\x00")
            break
        p = (p + ss + 3) & ~3
    mods.append((off, off + size, guid, name or guid))
    off = (off + size + 7) & ~7
print("FV modules:", len(mods))

for label, g in GUIDS.items():
    print("\n==", label)
    pos = 0
    while True:
        pos = fv.find(g, pos)
        if pos < 0:
            break
        owner = "FV header"
        for s, e, mg, mn in mods:
            if s <= pos < e:
                owner = "%s +0x%x" % (mn, pos - s)
                break
        print("  FV 0x%x  %s" % (pos, owner))
        pos += 1
    cnt = 0
    for root, _, files in os.walk(BIN):
        for f in files:
            if not f.lower().endswith(".efi"):
                continue
            name = os.path.basename(root)
            p = os.path.join(root, f)
            try:
                d = open(p, "rb").read()
            except OSError:
                continue
            if g in d:
                cnt += 1
                print("  BIN %s/%s" % (name, f))
    print("  binaries containing guid:", cnt)
