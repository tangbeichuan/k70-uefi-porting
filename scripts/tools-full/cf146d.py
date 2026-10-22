#!/usr/bin/env python3
"""cf146d.py -- authoritative check of what the FLASHED FD really contains:

  FD -> FFS -> LZMA GUID_DEFINED section -> FVMAIN -> per-module FFS -> parse PE

For UsbConfigDxe it prints the exact bytes at RVA 0x3FA8 (keys143 hardening site),
0x3FF0 (the keys142/keys144 crash site), 0x53CC/0x53D4 (keys145 guard), and reports
whether HALIOMMUDxe / ClockDxe are inside.

usage: python3 cf146d.py <fd> [<fd> ...]
"""
import lzma
import struct
import sys
import uuid

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
UCFG_GUID = "cd823a4d-7dec-4531-ae5d-4134fa4127b8"
HAL_GUID = "9a00771f-36d4-4dd5-8916-c48ed9b16b86"
CLOCK_GUID = "4db5dea6-5302-4d1a-8a82-677a683b0d29"


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


def walk_fv(buf, mods, label="FV"):
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
        ui = None
        for stype, sdata, sguid in sections(body):
            if stype == 0x15:
                ui = sdata.decode("utf-16-le", "ignore").rstrip("\x00")
            elif stype == 0x02 and sguid == LZMA_GUID:
                inner = lzma.decompress(sdata, format=lzma.FORMAT_ALONE)
                walk_fv(inner, mods, label + ">FVMAIN")
            elif stype == 0x17:
                walk_fv(sdata, mods, label + ">FV_IMAGE")
        if ftype not in (0x0B, 0xF0):
            mods.append(dict(guid=guid, name=ui or guid, body=body, off=off, size=size))
        off = (off + size + 7) & ~7


def check(path):
    fd = open(path, "rb").read()
    mods = []
    walk_fv(fd, mods)
    print("=" * 74)
    print(path, len(fd), "B;  modules walked:", len(mods))
    byguid = {m["guid"].lower(): m for m in mods}
    print("  HALIOMMUDxe FFS :", HAL_GUID in byguid)
    print("  ClockDxe FFS    :", CLOCK_GUID in byguid)
    m = byguid.get(UCFG_GUID)
    if not m:
        print("  !! UsbConfigDxe FFS not found")
        return
    body = m["body"]
    mz = body.find(b"MZ")
    print("  UsbConfigDxe FFS: off=0x%x size=%d MZ@body+0x%x" % (m["off"], m["size"], mz))
    pe = body[mz:]

    def word(rva):
        return pe[rva:rva + 4].hex() if 0 <= rva < len(pe) - 4 else "OOR"

    def i32(rva):
        return int.from_bytes(pe[rva:rva + 4], "little") if 0 <= rva < len(pe) - 4 else -1

    for rva, label in ((0x3FA8, "keys143 hardening (36f80208=OK / b6f80208=UNPATCHED)"),
                       (0x3FEC, "ldr gIommu (f943b508)"),
                       (0x3FF0, "crash site ldr x8,[x8,#8] (f9400508)"),
                       (0x53CC, "keys145 guard (280100b4=guarded / 080540f9=unguarded)"),
                       (0x53D4, "keys145 adrp (690000d0)")):
        print("    0x%04x %-58s = %s  (0x%08x)" % (rva, label, word(rva), i32(rva)))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        check(p)
