#!/usr/bin/env python3
"""List FFS files in FVMAIN.Fv (FV header + FFS walk), and show info about UsbConfigDxe entry."""
import struct
import os

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
data = open(FV, "rb").read()
print("size=0x%x mtime=%s" % (len(data), __import__("time").ctime(os.path.getmtime(FV))))

def guid(data, off):
    a, b, c = struct.unpack_from("<IHH", data, off)
    d = data[off + 8:off + 16]
    return "%08X-%04X-%04X-%s-%s" % (a, b, c, d[:2].hex().upper(), d[2:].hex().upper())

# FV header: 0x00 zero, 0x08 fsguid, 0x18 fvlen(8), 0x20 sig, 0x28 attr, 0x2c hdrlen(2), 0x30 checksum
fvlen = struct.unpack_from("<Q", data, 0x18)[0]
hdrlen = struct.unpack_from("<H", data, 0x2C)[0]
print("FV len=0x%x hdrlen=0x%x" % (fvlen, hdrlen))
p = hdrlen
n = 0
while p + 0x18 <= len(data) and n < 400:
    name = guid(data, p)
    ftype = data[p + 0x12]
    attr = data[p + 0x13]
    size = struct.unpack_from("<I", data, p + 0x14)[0]
    if size < 0x18 or p + size > len(data):
        # padding / end
        break
    state = data[p + 0x17] if False else None
    print("  off=0x%06x type=%02x attr=%02x size=0x%06x %s" % (p, ftype, attr, size, name))
    p += (size + 7) & ~7
    n += 1
print("total FFS entries:", n)
