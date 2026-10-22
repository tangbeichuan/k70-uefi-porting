#!/usr/bin/env python3
"""k151_moddiff.py -- extract one module body from two FDs and characterize its diff.
usage: k151_moddiff.py <fdA> <fdB> <guid>
"""
import hashlib, lzma, struct, sys, uuid

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"

def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
def gstr(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))

def mods(path):
    fd = open(path,'rb').read()
    out = {}
    hdr = fd.find(b"_FVH",0,0x1000); base = hdr-0x28
    off = base + u16(fd, base+0x30)
    while off + 0x18 <= base + u64(fd, base+0x20):
        ft = fd[off+0x12]
        sz = fd[off+0x14] | (fd[off+0x15]<<8) | (fd[off+0x16]<<16)
        if sz < 0x18 or ft == 0xFF: break
        body = fd[off+0x18:off+sz]
        so = 0
        while so + 4 <= len(body):
            ssz = body[so] | (body[so+1]<<8) | (body[so+2]<<16); st = body[so+3]
            if ssz < 4: break
            if st == 0x02 and ssz >= 24 and gstr(body, so+4) == LZMA_GUID:
                doff = so + u16(body, so+0x14)
                inner = lzma.decompress(body[doff:so+ssz], format=lzma.FORMAT_ALONE)
                o2 = 0x50
                while o2 + 0x18 <= len(inner):
                    t2 = inner[o2+0x12]
                    z2 = inner[o2+0x14] | (inner[o2+0x15]<<8) | (inner[o2+0x16]<<16)
                    if z2 < 0x18 or t2 == 0xFF: break
                    if t2 not in (0x0B,0xF0):
                        out[gstr(inner,o2)] = inner[o2+0x18:o2+z2]
                    o2 = (o2 + z2 + 7) & ~7
            so = (so + ssz + 3) & ~3
        off = (off + sz + 7) & ~7
    return out

def main(pa, pb, guid):
    a = mods(pa).get(guid); b = mods(pb).get(guid)
    print("guid", guid)
    print("A:", None if a is None else (len(a), hashlib.sha256(a).hexdigest()[:16]))
    print("B:", None if b is None else (len(b), hashlib.sha256(b).hexdigest()[:16]))
    if a is None or b is None: return
    n = min(len(a),len(b))
    diffs = [i for i in range(n) if a[i]!=b[i]]
    print("diff bytes:", len(diffs), "first:", hex(diffs[0]) if diffs else None, "last:", hex(diffs[-1]) if diffs else None)
    if diffs:
        clusters, s, p = [], diffs[0], diffs[0]
        for d in diffs[1:]:
            if d-p > 64: clusters.append((s,p)); s=d
            p=d
        clusters.append((s,p))
        print("clusters:", [(hex(x),hex(y)) for x,y in clusters][:12])
        for x,y in clusters[:4]:
            print("  A[%x:%x]=%s" % (x, y+1, a[x:y+1].hex()))
            print("  B[%x:%x]=%s" % (x, y+1, b[x:y+1].hex()))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3].lower())
