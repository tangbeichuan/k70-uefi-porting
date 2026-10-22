#!/usr/bin/env python3
"""k151_str.py -- list marker strings inside a module body extracted from an FD.
usage: k151_str.py <fd> <guid> <marker> [marker...]
"""
import lzma, struct, sys, uuid

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

if __name__ == "__main__":
    fd = sys.argv[1]
    guid = sys.argv[2].lower()
    markers = sys.argv[3:]
    body = mods(fd).get(guid)
    print(fd, guid, "size", None if body is None else len(body))
    if body is None: sys.exit(1)
    for m in markers:
        print("  %-40s %s" % (m, m.encode() in body))
