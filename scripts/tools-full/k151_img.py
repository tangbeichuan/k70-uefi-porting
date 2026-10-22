#!/usr/bin/env python3
"""k151_img.py -- inspect & compare Mu-vermeer-keys*.img files.
usage: k151_img.py <imgA> <imgB> [...]
"""
import sys, hashlib, struct

def find_all(b, pat):
    out, i = [], b.find(pat)
    while i >= 0:
        out.append(i); i = b.find(pat, i+1)
    return out

def info(path):
    b = open(path,'rb').read()
    print("="*78)
    print(path, len(b), "B sha256", hashlib.sha256(b).hexdigest())
    print("  head:", b[:64].hex())
    for pat in (b"_FVH", b"FVMAIN", b"SEC", b"vermeer", b"K70", b"USB150", b"MENU150"):
        loc = find_all(b, pat)[:6]
        print("  %-10s count=%d first=%s" % (pat.decode('latin1'), b.count(pat), [hex(x) for x in loc]))
    for pat in ("USB150", "MENU150"):
        p16 = pat.encode('utf-16-le')
        print("  %-10s utf16 count=%d first=%s" % (pat, b.count(p16), [hex(x) for x in find_all(b,p16)[:4]]))
    return b

def main(pa, pb):
    a = info(pa); b = info(pb)
    n = min(len(a), len(b))
    diffs = [i for i in range(n) if a[i] != b[i]]
    print("bytes differ:", len(diffs), "first:", hex(diffs[0]) if diffs else None, "last:", hex(diffs[-1]) if diffs else None)
    if diffs:
        # cluster diffs
        clusters, s, p = [], diffs[0], diffs[0]
        for d in diffs[1:]:
            if d - p > 0x1000:
                clusters.append((s,p)); s = d
            p = d
        clusters.append((s,p))
        print("clusters:", [(hex(x),hex(y)) for x,y in clusters][:20], "n=", len(clusters))

if __name__ == "__main__":
    if len(sys.argv) == 3:
        main(sys.argv[1], sys.argv[2])
    else:
        for p in sys.argv[1:]:
            info(p)
