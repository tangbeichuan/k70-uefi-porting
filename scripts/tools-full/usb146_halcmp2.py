#!/usr/bin/env python3
"""usb146_halcmp2.py -- locate HALIOMMU FFS inside keys145 FVMAIN, extract its
PE image, compare with the Binaries HALIOMMUDxe.efi, and inspect the protocol
interface struct at .data VA 0xd0b8 plus .reloc coverage of 0xd0c0..0xd148."""
import struct
import hashlib
import uuid

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
HAL = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi"
HAL_GUID = "9a00771f-36d4-4dd5-8916-c48ed9b16b86"


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
        ssize = fv[p] | (fv[p + 1] << 8) | (fv[p + 2] << 16)
        stype = fv[p + 3]
        if ssize < 4:
            break
        if stype == 0x15:
            name = fv[p + 4: p + ssize].decode("utf-16-le", "ignore").rstrip("\x00")
            break
        p = (p + ssize + 3) & ~3
    mods.append((off, off + size, guid, name))
    off = (off + size + 7) & ~7

hit = None
for s, e, g, n in mods:
    if (n and "HALIOMMU" in n.upper()) or g.startswith("9a00771f"):
        hit = (s, e, g, n)
        break
print("modules:", len(mods), "HALIOMMU FFS:", hit)
if hit is None:
    for s, e, g, n in mods:
        print("  ", hex(s), hex(e), g, n)
    raise SystemExit(1)

s, e, g, n = hit
ffs = fv[s:e]
mz = None
p = s + 0x18
while p + 4 <= e:
    ssize = fv[p] | (fv[p + 1] << 8) | (fv[p + 2] << 16)
    stype = fv[p + 3]
    if ssize < 4:
        break
    if stype == 0x10 and fv[p + 4:p + 6] == b"MZ":
        mz = p + 4
        break
    p = (p + ssize + 3) & ~3
print("PE32 offset in FV: 0x%x (FFS +0x%x)" % (mz, mz - s))
pe = fv[mz:]
pe = pe[:struct.unpack_from("<I", pe, 0x3c)[0] + 0x18 +
        struct.unpack_from("<H", pe, 0x14)[0] * 40]  # crude trim not needed
bin_ = open(HAL, "rb").read()
print("Binaries len", len(bin_), "sha", hashlib.sha256(bin_).hexdigest()[:16])

# take PE image length from Binaries size (same module)
pe = fv[mz:mz + len(bin_)]
print("FV payload len", len(pe), "sha", hashlib.sha256(pe).hexdigest()[:16],
      "identical:", pe == bin_)

# sections
peh = pe.find(b"PE\x00\x00")
nsec = struct.unpack_from("<H", pe, peh + 6)[0]
opt = peh + 24
magic = struct.unpack_from("<H", pe, opt)[0]
so = opt + (0xf0 if magic == 0x20b else 0xe0)
secs = []
for i in range(nsec):
    q = so + i * 40
    nm = pe[q:q + 8].rstrip(b"\0").decode()
    vsize, va, rsize, raw = struct.unpack_from("<IIII", pe, q + 8)
    secs.append((nm, va, vsize, rsize, raw))
print("sections:", secs)
dat = [x for x in secs if x[0] == ".data"][0]
_, dva, dvsize, drsize, draw = dat


def rd(va, length):
    return pe[draw + (va - dva): draw + (va - dva) + length]


print("\nFV HALIOMMU .data @0xd0b0..0xd150:")
for r in range(0xb0, 0x150, 0x10):
    print("  0x%05x %s" % (0xd000 + r, rd(0xd000 + r, 16).hex(" ")))

# .reloc coverage
rel = [x for x in secs if x[0] == ".reloc"]
tg = set()
if rel:
    _, rva, rvsize, rrsize, rraw = rel[0]
    blob = pe[rraw:rraw + rrsize]
    p = 0
    while p + 8 <= len(blob):
        page, bs = struct.unpack_from("<II", blob, p)
        if bs < 8:
            break
        for q in range(p + 8, p + bs, 2):
            ent = struct.unpack_from("<H", blob, q)[0]
            if ent == 0:
                continue
            typ, ofs = ent >> 12, ent & 0xfff
            tg.add((typ, page + ofs))
        p += bs
inr = sorted(hex(o) for t, o in tg if 0xd0b8 <= o <= 0xd150)
print("\nreloc entries inside iface struct 0xd0b8..0xd150:", inr)
print("reloc types sample:", sorted(set(t for t, o in tg)))
# all relocs in .data range
indata = [(t, o) for t, o in tg if dva <= o < dva + drsize]
print("relocs in .data:", len(indata),
      "first:", [(t, hex(o)) for t, o in sorted(indata, key=lambda x: x[1])[:12]])
# what is at d218 (gBS?) 
print("\n0xd210..0xd230:", rd(0xd210, 0x20).hex(" "))
