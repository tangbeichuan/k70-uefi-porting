#!/usr/bin/env python3
"""k151_struct.py -- structural diff of two FDs: outer FV, FFS entries, LZMA payload,
inner FVMAIN layout (nested FVs), and trailing bytes.
usage: k151_struct.py <fdA> <fdB>
"""
import lzma, struct, sys, uuid, hashlib

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
FV_GUID = "8c8ce578-8a3d-4f1c-9935-896185c32dd3"

def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u32(b,o): return struct.unpack_from("<I",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
def gstr(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))
def sha(b): return hashlib.sha256(b).hexdigest()[:16]

def sections(body):
    out, off = [], 0
    while off + 4 <= len(body):
        size = body[off] | (body[off+1]<<8) | (body[off+2]<<16)
        stype = body[off+3]
        if size < 4: break
        doff, sguid = off+4, None
        if stype == 0x02 and size >= 24:
            sguid = gstr(body, off+4); doff = off + u16(body, off+0x14)
        out.append((stype, body[doff:off+size], sguid, off, size))
        off = (off + size + 3) & ~3
    return out

def fv_header(buf, at=0):
    hdr = buf.find(b"_FVH", at, at+0x1000)
    if hdr < 0: return None
    base = hdr - 0x28
    return dict(base=base, len=u64(buf, base+0x20), hdrlen=u16(buf, base+0x30),
                fst=base+u16(buf, base+0x30), ext=u32(buf, base+0x34))

def ffs_entries(buf):
    h = fv_header(buf)
    out = []
    if not h: return out, None
    off = h["fst"]; end = min(len(buf), h["base"]+h["len"])
    while off + 0x18 <= end:
        ftype = buf[off+0x12]
        size = buf[off+0x14] | (buf[off+0x15]<<8) | (buf[off+0x16]<<16)
        if size < 0x18 or ftype == 0xFF: break
        out.append(dict(off=off, size=size, type=ftype, guid=gstr(buf, off),
                        body=buf[off+0x18:off+size]))
        off = (off + size + 7) & ~7
    return out, h

def report(path):
    fd = open(path,'rb').read()
    print("="*78)
    print(path, len(fd), "B sha", sha(fd))
    entries, h = ffs_entries(fd)
    print("outer FV:", {k: (hex(v) if isinstance(v,int) else v) for k,v in h.items()} if h else None)
    for e in entries:
        print("  FFS @0x%x size=%d type=0x%x guid=%s body_sha=%s" %
              (e["off"], e["size"], e["type"], e["guid"], sha(e["body"])))
        for stype, sdata, sguid, soff, ssize in sections(e["body"]):
            print("    sec type=0x%02x off=0x%x size=%d guid=%s sha=%s" %
                  (stype, soff, ssize, sguid, sha(sdata)))
            if stype == 0x02 and sguid == LZMA_GUID:
                inner = lzma.decompress(sdata, format=lzma.FORMAT_ALONE)
                print("      LZMA outer=0x%x bytes -> inner 0x%x bytes sha=%s" %
                      (len(sdata), len(inner), sha(inner)))
                ih = fv_header(inner)
                print("      inner FV hdr:", {k: (hex(v) if isinstance(v,int) else v) for k,v in ih.items()} if ih else None)
                for se in [s for s in ffs_entries(inner)[0]]:
                    print("        inner FFS @0x%x size=%d type=0x%x guid=%s" % (se["off"], se["size"], se["type"], se["guid"]))
                    for t2, d2, g2, o2, s2 in sections(se["body"]):
                        extra = ""
                        if t2 == 0x17:
                            sub = fv_header(d2)
                            extra = " nestedFV:%s" % ({k:(hex(v) if isinstance(v,int) else v) for k,v in sub.items()} if sub else None)
                        print("          sec type=0x%02x off=0x%x size=%d guid=%s sha=%s%s" % (t2,o2,s2,g2,sha(d2),extra))
    tail_start = (h["base"]+h["len"]) if h else len(fd)
    tail = fd[tail_start:]
    print("trailing after FV: 0x%x bytes sha=%s first16=%s" % (len(tail), sha(tail), tail[:16].hex()))
    return fd

if __name__ == "__main__":
    a = report(sys.argv[1])
    b = report(sys.argv[2])
    n = min(len(a), len(b))
    diffs = [i for i in range(n) if a[i] != b[i]]
    print("bytes differ:", len(diffs), "first:", hex(diffs[0]) if diffs else None, "last:", hex(diffs[-1]) if diffs else None)
