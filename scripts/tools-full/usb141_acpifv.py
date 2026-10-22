#!/usr/bin/env python3
"""Check whether AcpiTableDxe (and gEfiAcpiSdtProtocolGuid producer) is inside FVMAIN.Fv."""
import struct
import subprocess
import re

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"


def gb(s):
    q = s.split("-")
    return struct.pack("<IHH", int(q[0], 16), int(q[1], 16), int(q[2], 16)) + bytes.fromhex(q[3] + q[4])


data = open(FV, "rb").read()
print("FV size=0x%x" % len(data))
for name, g in [("FILE:AcpiTableDxe", "9622E42C-8E38-4a08-9E8F-54F784652F6B"),
                ("gEfiAcpiSdtProtocolGuid", "EB97088E-CFDF-49C6-BE4B-D906A5B20E86"),
                ("gEfiAcpiTableProtocolGuid", "FFE06BDD-6107-46A6-7BB2-5A9C7EC5275C"),
                ("FILE:AcpiPlatform", "cb933912-df8f-4305-b1f9-7b44fa11395c")]:
    pat = gb(g)
    off = 0
    hits = []
    while True:
        i = data.find(pat, off)
        if i < 0:
            break
        hits.append(i)
        off = i + 1
    print("  %-28s %-38s count=%d %s" % (name, g, len(hits), ["0x%x" % h for h in hits]))

# walk FFS entries properly (3-byte size)
print()
print("=== FFS walk (3-byte size) ===")
hdrlen = struct.unpack_from("<H", data, 0x30)[0]
p = hdrlen
n = 0
acpi_off = None
while p + 0x18 <= len(data):
    g = data[p:p + 16]
    if g == b"\xff" * 16 or g == b"\x00" * 16:
        print("  end/padding at 0x%x" % p)
        break
    size = data[p + 0x14] | (data[p + 0x15] << 8) | (data[p + 0x16] << 16)
    if size < 0x18 or p + size > len(data):
        print("  bad FFS at 0x%x size=0x%x" % (p, size))
        break
    typ = data[p + 0x12]
    if n < 100:
        nm = "%08X-%04X-%04X-%s-%s" % (*struct.unpack_from("<IHH", g, 0), g[8:10].hex().upper(), g[10:].hex().upper())
        print("  0x%06x type=%02x size=0x%06x %s" % (p, typ, size, nm))
    if g == gb("9622E42C-8E38-4a08-9E8F-54F784652F6B"):
        acpi_off = (p, size)
        print("  >>> AcpiTableDxe FFS found at 0x%x size=0x%x <<<" % (p, size))
    p += (size + 7) & ~7
    n += 1
print("entries:", n)
if acpi_off:
    p, size = acpi_off
    payload = data[p + 0x18:p + size]
    print("  payload has SDT GUID:", payload.count(gb("EB97088E-CFDF-49C6-BE4B-D906A5B20E86")))
