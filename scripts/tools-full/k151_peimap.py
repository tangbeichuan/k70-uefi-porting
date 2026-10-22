#!/usr/bin/env python3
"""k151_peimap.py -- prove whether the PEI memory-map table (MemoryMapLib) inside a
keys* FD contains the "USB 0x0A600000" region, by scanning the SEC/PEI payload for
the region-name table and the 0x0A600000 little-endian address.
usage: k151_peimap.py <fd> [...]
"""
import struct, sys, uuid

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"

def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u32(b,o): return struct.unpack_from("<I",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
def gstr(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))

def find_all(b, pat):
    out, i = [], b.find(pat)
    while i >= 0:
        out.append(i); i = b.find(pat, i+1)
    return out

def dump(path):
    fd = open(path,'rb').read()
    print("="*78); print(path, len(fd), "B")
    # SECURITY_CORE FFS at 0x48 contains the PEI payload (plain, uncompressed)
    hdr = fd.find(b"_FVH", 0, 0x1000); base = hdr-0x28
    fst = base + u16(fd, base+0x30)
    off = fst
    while off + 0x18 <= len(fd):
        ftype = fd[off+0x12]
        size = fd[off+0x14] | (fd[off+0x15]<<8) | (fd[off+0x16]<<16)
        if size < 0x18 or ftype == 0xFF: break
        guid = gstr(fd, off); body = fd[off+0x18:off+size]
        print("  FFS off=0x%x type=0x%02x size=%d guid=%s" % (off, ftype, size, guid))
        # walk sections
        so = 0
        while so + 4 <= len(body):
            ssize = body[so] | (body[so+1]<<8) | (body[so+2]<<16); stype = body[so+3]
            if ssize < 4: break
            sdata = body[so+4:so+ssize]
            print("    sec type=0x%02x size=%d" % (stype, ssize))
            for name in (b"USB\x00", b"PERIPH_SS", b"UFS", b"MMAP_IO"):
                print("       %-10s count=%d" % (name.decode('latin1').strip('\x00'), sdata.count(name)))
            a = struct.pack("<Q", 0x0A600000); a4 = struct.pack("<I", 0x0A600000)
            print("       0x0A600000 qword@%s u32@%s" %
                  ([hex(x) for x in find_all(sdata, a)][:8], [hex(x) for x in find_all(sdata, a4)][:8]))
            # region entry candidates: name ptr near 0x0A600000 words
            so = (so + ssize + 3) & ~3
        off = (off + size + 7) & ~7

if __name__ == "__main__":
    for p in sys.argv[1:]:
        dump(p)
