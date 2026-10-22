#!/usr/bin/env python3
"""k152_menucheck.py <fd> -- list FVMAIN modules and UTF-16 marker counts."""
import struct
import sys
import lzma

LZMA_GUID = bytes.fromhex("98584eee143959429d6edc7bd79403cf")
MARKERS = ["MENU152", "USB152", "MENU150", "UI152", "USBDIAG", "CpuDeadLoop", "no writes"]


def walk(buf, base, end):
    off = base
    out = []
    while off + 24 <= end:
        nm = buf[off:off + 16]
        ic, typ, attr = struct.unpack_from("<HBB", buf, off + 16)
        size = struct.unpack_from("<I", buf, off + 20)[0] & 0xFFFFFF
        if typ in (0xFF, 0) or size < 24:
            break
        out.append((off, typ, size, nm))
        off += (size + 7) & ~7
    return out


def main():
    fd = open(sys.argv[1], "rb").read()
    for fo, t, s, nm in walk(fd, 0x48, len(fd)):
        body = fd[fo + 24:fo + s]
        if t == 0x0B and LZMA_GUID in body:
            gi = body.find(LZMA_GUID)
            dec = lzma.decompress(body[gi + 20:], format=lzma.FORMAT_ALONE)
            hv = dec.find(b"_FVH")
            base = hv - 0x28
            flen = struct.unpack_from("<Q", dec, base + 0x20)[0]
            print("inner FV len=0x%x" % flen)
            mods = walk(dec, base + 0x50, base + flen)
            for fo2, t2, s2, nm2 in mods:
                g = "%08X-%04X-%04X" % struct.unpack_from("<IHH", nm2, 0)
                pl = dec[fo2 + 24:fo2 + s2]
                if s2 >= 18000 and b"MZ" in pl:
                    print("  module %s type=0x%02x size=%d" % (g, t2, s2))
                    for m in MARKERS:
                        c = pl.count(m.encode("utf-16-le"))
                        ca = pl.count(m.encode())
                        if c or ca:
                            print("     %-12s utf16=%d ascii=%d" % (m, c, ca))
    return 0


if __name__ == "__main__":
    sys.exit(main())
