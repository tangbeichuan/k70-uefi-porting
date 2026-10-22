#!/usr/bin/env python3
"""k152_secdiff.py -- compare one module between two FD images (PE section tables).
usage: k152_secdiff.py <fdA> <fdB> [module-substr]
default module = LogDisk
"""
import struct
import sys
import lzma

LZMA_GUID = bytes.fromhex("98584eee14395942" "9d6edc7bd79403cf")  # ee4e5898-3914-4259-9d6e-dc7bd79403cf


def ffs_walk(buf, base, limit=None):
    out = []
    off = base
    end = limit or len(buf)
    while off + 24 <= end:
        name = buf[off:off + 16]
        ic, typ, attr = struct.unpack_from("<HBB", buf, off + 16)
        size = struct.unpack_from("<I", buf, off + 20)[0] & 0xFFFFFF
        if typ in (0xFF, 0x00) or size < 24:
            break
        out.append((off, typ, size, name))
        off += (size + 7) & ~7
    return out


def pe_from_ffs(body):
    """walk sections of an FFS payload, return PE32 bytes (search MZ fallback)."""
    off = 0
    while off + 4 <= len(body):
        ssize = struct.unpack_from("<I", body, off)[0] & 0xFFFFFF
        stype = body[off + 3]
        if ssize < 4:
            break
        if stype == 0x10:
            return body[off + 4:off + ssize]
        if stype == 0x02:  # GUIDed section
            if body[off + 4:off + 20] == LZMA_GUID:
                dlen = struct.unpack_from("<I", body, off + 4 + 16 + 2 + 2)[0]
                data = body[off + 24:]
                return None
        if stype == 0x17:  # nested FV
            return None
        off += (ssize + 3) & ~3
    idx = body.find(b"MZ")
    return body[idx:] if idx >= 0 else None


def pe_sections(pe):
    e_lfanew = struct.unpack_from("<I", pe, 0x3C)[0]
    assert pe[e_lfanew:e_lfanew + 4] == b"PE\0\0"
    coff = e_lfanew + 4
    nsec = struct.unpack_from("<H", pe, coff + 2)[0]
    opt = coff + 20
    magic = struct.unpack_from("<H", pe, opt)[0]
    dd = opt + (0x70 if magic == 0x20B else 0x60)
    sec = dd + struct.unpack_from("<H", pe, coff + 16)[0]
    rows = []
    for i in range(nsec):
        h = sec + i * 40
        nm = pe[h:h + 8].rstrip(b"\0").decode("ascii", "replace")
        vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", pe, h + 8)
        rows.append((nm, vsize, vaddr, rawsize, rawptr))
    return magic, len(pe), rows


def load(fd_path, want):
    fd = open(fd_path, "rb").read()
    subs = []
    for ffs_off, typ, size, name in ffs_walk(fd, 0x48):
        body = fd[ffs_off + 24:ffs_off + size]
        if typ == 0x0B and LZMA_GUID in body:
            gi = body.find(LZMA_GUID)
            data = body[gi + 16 + 4:]
            dec = lzma.decompress(data, format=lzma.FORMAT_ALONE)
            hv = dec.find(b"_FVH")
            base = hv - 0x28
            for fo, ft, fs, fn in ffs_walk(dec, base + 0x50, base + struct.unpack_from("<Q", dec, base + 0x20)[0]):
                nm = "%08X-%04X-%04X" % struct.unpack_from("<IHH", fn, 0)
                subs.append((nm, dec[fo + 24:fo + fs], fn, fs))
            break
    for nm, payload, guid, fs in subs:
        pe = pe_from_ffs(payload)
        if pe is None:
            continue
        magic, ln, rows = pe_sections(pe)
        txt = b"".join(pe[rawptr:rawptr + rawsize] for (n, v, va, rawsize, rawptr) in rows)
        wb = want.lower().encode()
        if wb in txt.lower() or (wb == b"logdisk" and b"LOGDISK" in txt):
            return nm, ln, rows, txt
    return None


def main():
    a, b = sys.argv[1], sys.argv[2]
    want = sys.argv[3] if len(sys.argv) > 3 else "logdisk"
    ra = load(a, want)
    rb = load(b, want)
    if not ra or not rb:
        print("module not found:", bool(ra), bool(rb))
        return 1
    print("A:", ra[0], "file_size=", ra[1])
    for r in ra[2]:
        print("   %-8s vsize=0x%06x vaddr=0x%05x rawlen=0x%06x off=0x%06x" % r)
    print("B:", rb[0], "file_size=", rb[1])
    for r in rb[2]:
        print("   %-8s vsize=0x%06x vaddr=0x%05x rawlen=0x%06x off=0x%06x" % r)
    ta, tb = ra[3], rb[3]
    print("text bytes A=%d B=%d identical=%s" % (len(ta), len(tb), ta == tb))
    if len(ta) == len(tb) and ta != tb:
        diffs = [i for i in range(len(ta)) if ta[i] != tb[i]]
        print("differing bytes=%d first=%s" % (len(diffs), [hex(i) for i in diffs[:20]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
