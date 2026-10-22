#!/usr/bin/env python3
"""usb146_halcmp.py -- extract HALIOMMUDxe from keys145 FVMAIN and compare its
.data interface struct (expected at VA 0xd0b8) with the Binaries copy; also
check .reloc coverage for the interface function-pointer fields."""
import struct
import hashlib
import uuid

FD = "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd"
FVF = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
HAL = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi"


def pe_sections(d):
    pe = d.find(b"PE\x00\x00")
    nsec = struct.unpack_from("<H", d, pe + 6)[0]
    opt = pe + 24
    magic = struct.unpack_from("<H", d, opt)[0]
    so = opt + (0xf0 if magic == 0x20b else 0xe0)
    secs = []
    for i in range(nsec):
        s = so + i * 40
        name = d[s:s + 8].rstrip(b"\0").decode()
        vsize, va, rsize, raw = struct.unpack_from("<IIII", d, s + 8)
        secs.append((name, va, vsize, rsize, raw))
    return secs


def reloc_targets(d):
    secs = pe_sections(d)
    r = [s for s in secs if s[0] == ".reloc"]
    if not r:
        return set()
    name, va, vsize, rsize, raw = r[0]
    blob = d[raw:raw + rsize]
    out = set()
    p = 0
    while p + 8 <= len(blob):
        page, bsize = struct.unpack_from("<II", blob, p)
        if bsize < 8:
            break
        for q in range(p + 8, p + bsize, 2):
            e = struct.unpack_from("<H", blob, q)[0]
            if e == 0:
                continue
            typ, off = e >> 12, e & 0xfff
            if typ in (3, 10, 2, 0xB):
                out.add(page + off)
        p += bsize
    return out

fv = open(FVF, "rb").read()
hv = fv.find(b"_FVH", 0, 0x1000)
base = hv - 0x28
hdrlen = struct.unpack_from("<H", fv, base + 0x30)[0]
off = base + hdrlen
target = None
target_name = None
while off + 0x18 <= len(fv):
    t = fv[off + 0x12]
    size = fv[off + 0x14] | (fv[off + 0x15] << 8) | (fv[off + 0x16] << 16)
    if size < 0x18 or t == 0xFF:
        break
    guid = str(uuid.UUID(bytes_le=fv[off:off + 16]))
    p = off + 0x18
    while p + 4 <= off + size:
        ss = fv[p] | (fv[p + 1] << 8) | (fv[p + 2] << 16)
        st = fv[p + 3]
        if ss < 4:
            break
        if st == 0x15:
            target_name = fv[p + 4: p + ss].decode("utf-16-le", "ignore").rstrip("\x00")
        if st == 0x19 and target_name and "HALIOMMU" in target_name.upper():
            target = fv[p + 4: p + ss - 4]
        p = (p + ss + 3) & ~3
    off = (off + size + 7) & ~7

print("FV HALIOMMU found:", target is not None, "len", len(target) if target else 0)
bin_ = open(HAL, "rb").read()
print("Binaries HALIOMMU len", len(bin_), "sha", hashlib.sha256(bin_).hexdigest()[:16])
if target:
    print("FV copy payload len", len(target), "sha", hashlib.sha256(target).hexdigest()[:16])
    print("identical:", target == bin_)
    d = target
    secs = pe_sections(d)
    print("sections", secs)
    # find .data raw/va
    dat = [s for s in secs if s[0] == ".data"][0]
    _, dva, dvsize, drsize, draw = dat
    def rd(va, n):
        o = draw + (va - dva)
        return d[o:o + n]
    print("\nFV copy .data @0xd0b0..0xd100:")
    for r in range(0xb0, 0x100, 0x10):
        print("  0xd0%02x %s" % (r, rd(0xd000 + r, 16).hex(" ")))
    rl = reloc_targets(d)
    print("\nreloc targets in 0xd0b8..0xd148?",
          sorted(hex(x) for x in rl if 0xd0b8 <= x <= 0xd148)[:25])
    print("total reloc targets", len(rl))
    # who references 0xd0b8 in code (adrp 0xd000/add 0xb8)
    print("\nGUID bytes in FV copy:", d.find(bytes.fromhex("b4d3b654335d914f86006c41d5deb19a")))
