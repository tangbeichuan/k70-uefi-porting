#!/usr/bin/env python3
"""Parse FVMAIN.Fv FFS list and map protocol GUID occurrences to FFS modules."""
import struct
import time

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
GUIDS = {
    "B0760469-970C-487A-A4B5-28DB7B45CEF1": "ChipInfo",
    "FA5F306B-F47D-4AC4-A47D-882F8204EC30": "SPMI",
    "F4E5C7D0-D239-47CB-AACD-7F66EF763238": "SMEM",
    "157A5C45-21B2-43C5-BA7C-822FEE5FE599": "PlatformInfo",
    "EB97088E-CFDF-49C6-BE4B-D906A5B20E86": "EB97088E(unknown)",
    "E722B03F-B250-42CE-8EBD-5BD51812D037": "E722B03F(UsbInitDxe dep)",
    "4684800A-2755-4EDC-B443-7F8CEB3239D3": "PmicVersion",
    "CD823A4D-7DEC-4531-AE5D-4134FA4127B8": "FILE:UsbConfigDxe",
    "3F6C1D92-85B4-4E27-9C63-1A8F5D2E7B04": "FILE:VermeerPmicVerStubDxe",
    "5AF77F10-90DF-4E7E-8325-A17EC09D5443": "FILE:UsbMsdDxe",
    "0A134F0E-075E-40B3-9C63-3B3906804663": "FILE:UsbInitDxe",
    "94F8A6A7-DC34-4101-88C1-99179CCEAE83": "FILE:UsbfnDwc3Dxe",
}


def gb(s):
    q = s.split("-")
    return struct.pack("<IHH", int(q[0], 16), int(q[1], 16), int(q[2], 16)) + bytes.fromhex(q[3] + q[4])


data = open(FV, "rb").read()
print("size=0x%x mtime=%s" % (len(data), time.ctime(__import__("os").path.getmtime(FV))))
fvlen = struct.unpack_from("<Q", data, 0x20)[0]
hdrlen = struct.unpack_from("<H", data, 0x30)[0]
print("FV len=0x%x hdrlen=0x%x" % (fvlen, hdrlen))

p = hdrlen
mods = []
while p + 0x18 <= min(len(data), fvlen):
    g = data[p:p + 16]
    if g == b"\xff" * 16:
        break
    size = data[p + 0x14] | (data[p + 0x15] << 8) | (data[p + 0x16] << 16)
    if size < 0x18 or p + size > len(data):
        print("  bad FFS at 0x%x size=0x%x" % (p, size))
        break
    mods.append((p, size, g))
    p += (size + 7) & ~7

print("FFS entries: %d" % len(mods))
pats = {k: gb(k) for k in GUIDS}
print()
print("%-8s %-10s %s" % ("offset", "size", "GUIDs found inside payload"))
for off, size, g in mods:
    payload = data[off + 0x18:off + size]
    hits = []
    for k, pat in pats.items():
        c = payload.count(pat)
        if c:
            hits.append("%s x%d" % (GUIDS[k], c))
    if hits:
        print("0x%06x 0x%07x  %-38s %s" % (off, size, "%08X-%04X-%04X" % struct.unpack_from("<IHH", g, 0), hits))

print()
print("=== FFS file GUID name resolution (from Guid.xref) ===")
xref = {}
for ln in open("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref", errors="replace"):
    parts = ln.split()
    if len(parts) >= 2:
        xref[parts[0].upper()] = parts[1]
for off, size, g in mods:
    name = "%08X-%04X-%04X-%s-%s" % (
        *struct.unpack_from("<IHH", g, 0), g[8:10].hex().upper(), g[10:].hex().upper())
    nm = xref.get(name, "")
    if nm:
        print("0x%06x 0x%06x %-36s %s" % (off, size, name, nm))
