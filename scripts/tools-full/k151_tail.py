#!/usr/bin/env python3
"""k151_tail.py -- compare the non-gzip tail inside the kernel payload of two imgs,
and identify its nature (magic, structure).
usage: k151_tail.py <imgA> <imgB>
"""
import hashlib, struct, sys, zlib

def load(path):
    b = open(path,'rb').read()
    ks = struct.unpack_from("<I", b, 8)[0]
    ps = struct.unpack_from("<I", b, 0x24)[0] or 0x800
    p = b[ps:ps+ks]
    d = zlib.decompressobj(31)
    data = d.decompress(p) + d.flush()
    consumed = len(p) - len(d.unused_data)
    tail = p[consumed:]
    return dict(path=path, b=b, payload=p, dec=data, consumed=consumed, tail=tail)

def main(pa, pb):
    a = load(pa); b = load(pb)
    for o in (a, b):
        print("="*74)
        print(o['path'])
        print("  gzip consumed=%d  decomp=%d  tail=%d" % (o['consumed'], len(o['dec']), len(o['tail'])))
        print("  tail head64:", o['tail'][:64].hex())
        print("  tail sha:", hashlib.sha256(o['tail']).hexdigest())
        for pat in (b"vermeer", b"_FVH", b"\x1f\x8b", b"K70", b"LOG"):
            print("    %-10s count=%d first=%s" % (pat.decode('latin1'), o['tail'].count(pat),
                  [hex(x) for x in [o['tail'].find(pat)] if x>=0]))
    ta, tb = a['tail'], b['tail']
    n = min(len(ta), len(tb))
    diffs = [i for i in range(n) if ta[i] != tb[i]]
    print("tail differing bytes:", len(diffs), "first:", hex(diffs[0]) if diffs else None)
    if len(ta) == len(tb) and not diffs:
        print("TAILS IDENTICAL (same length and bytes)")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
