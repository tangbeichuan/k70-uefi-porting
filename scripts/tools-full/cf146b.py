#!/usr/bin/env python3
"""cf146b.py -- decompress the FVMAIN payload inside a SILICIUM_UEFI-keysNNN.fd and
report whether UsbConfigDxe carries the keys143 0x3FA8 hardening (36f80208) or the
original instruction (b6f80208). Also locates the 0x3FF0 NULL-deref site.

usage: python3 cf146b.py /path/to/SILICIUM_UEFI-keys144.fd [keys145.fd ...]
"""
import gzip
import io
import sys
import zlib


def load_fv(path):
    d = open(path, "rb").read()
    out = []
    start = 0
    while True:
        i = d.find(b"\x1f\x8b\x08", start)
        if i < 0:
            break
        try:
            dec = gzip.GzipFile(fileobj=io.BytesIO(d[i:])).read()
        except Exception:
            try:
                dec = zlib.decompressobj(31).decompress(d[i:])
            except Exception:
                dec = b""
        if dec:
            out.append((i, dec))
            start = i + 1
        else:
            start = i + 1
    return d, out


def main():
    for path in sys.argv[1:]:
        d, chunks = load_fv(path)
        print("=" * 70)
        print(path, "file size", len(d))
        print("gzip streams:", [(hex(o), len(c)) for o, c in chunks])
        blob = b"".join(c for _, c in chunks)
        print("decompressed total:", len(blob))
        for name, pat in (("ORIGINAL b6f80208 (tbz x8,#0x3f, unhardened)", "b6f80208"),
                          ("HARDENED 36f80208 (tbz w8,#0x1f)", "36f80208"),
                          ("HARDENED 280100b4 (cbz x8,0x53f0 keys145)", "280100b4"),
                          ("0x3ff0 site f9400508", "f9400508"),
                          ("gIommu global adrp+ldr (90000088 f943b508)", "90000088f943b508")):
            p = bytes.fromhex(pat)
            print("  %-46s count=%d" % (name, blob.count(p)))
        # locate window around any hardened/original tbz
        for tag, pat in (("HARD", "36f80208"), ("ORIG", "b6f80208")):
            p = bytes.fromhex(pat)
            i = blob.find(p)
            if i >= 0:
                ctx = blob[i - 8:i + 24]
                print("  %s at 0x%x ctx=%s" % (tag, i, ctx.hex()))


if __name__ == "__main__":
    main()
