#!/usr/bin/env python3
"""cf146e.py -- extract UsbConfigDxe as it exists INSIDE a built FD, write it to
/tmp/<name>.efi so llvm-objdump can decode the patched instructions.

usage: python3 cf146e.py <fd> <out.efi>
"""
import lzma
import struct
import sys
import uuid

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
UCFG_GUID = "cd823a4d-7dec-4531-ae5d-4134fa4127b8"


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def gstr(b, o):
    return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))


def sections(body):
    out, off = [], 0
    while off + 4 <= len(body):
        size = body[off] | (body[off + 1] << 8) | (body[off + 2] << 16)
        stype = body[off + 3]
        if size < 4:
            break
        data_off, sguid = off + 4, None
        if stype == 0x02 and size >= 24:
            sguid = gstr(body, off + 4)
            data_off = off + u16(body, off + 0x14)
        out.append((stype, body[data_off:off + size], sguid))
        off = (off + size + 3) & ~3
    return out


def walk_fv(buf, mods):
    hdr = buf.find(b"_FVH", 0, 0x1000)
    if hdr < 0:
        return
    base = hdr - 0x28
    fv_len = u64(buf, base + 0x20)
    off = base + u16(buf, base + 0x30)
    end = min(len(buf), base + fv_len)
    while off + 0x18 <= end:
        ftype = buf[off + 0x12]
        size = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        if size < 0x18 or ftype == 0xFF:
            break
        guid = gstr(buf, off)
        body = buf[off + 0x18: off + size]
        for stype, sdata, sguid in sections(body):
            if stype == 0x02 and sguid == LZMA_GUID:
                walk_fv(lzma.decompress(sdata, format=lzma.FORMAT_ALONE), mods)
            elif stype == 0x17:
                walk_fv(sdata, mods)
        if ftype not in (0x0B, 0xF0):
            mods.append(dict(guid=guid, body=body))
        off = (off + size + 7) & ~7


fd = open(sys.argv[1], "rb").read()
mods = []
walk_fv(fd, mods)
m = next(m for m in mods if m["guid"].lower() == UCFG_GUID)
mz = m["body"].find(b"MZ")
pe = m["body"][mz:]
open(sys.argv[2], "wb").write(pe)
print("wrote", sys.argv[2], len(pe), "bytes; PE rva of MZ was body+0x%x" % mz)
