#!/usr/bin/env python3
"""usb146_hal.py -- inspect HALIOMMUDxe install of GUID 54B6D3B4 and the
interface struct it publishes; also dump UsbConfigDxe globals 0x136e0-0x13800.
"""
import struct

def loads(path):
    d = open(path, "rb").read()
    pe = d.find(b"PE\x00\x00")
    nsec = struct.unpack_from("<H", d, pe + 6)[0]
    opt = pe + 24
    magic = struct.unpack_from("<H", d, opt)[0]
    off = opt + (0x70 if magic == 0x20b else 0x60)
    secs = []
    for i in range(nsec):
        s = opt + (0xf0 if magic == 0x20b else 0xe0) + i * 40
        name = d[s:s + 8].rstrip(b"\x00").decode()
        vsize, va, rsize, raw = struct.unpack_from("<IIII", d, s + 8)
        secs.append((name, va, vsize, raw, rsize))
    return d, secs

def va2off(secs, va):
    for name, sva, vsize, raw, rsize in secs:
        if sva <= va < sva + max(vsize, rsize):
            return raw + (va - sva)
    return None

H = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi"
d, secs = loads(H)
print("HALIOMMU sections:", secs)
print("file size", len(d), "GUID fileoff 0xd068 -> va?", )
for name, sva, vsize, raw, rsize in secs:
    if raw <= 0xd068 < raw + rsize:
        print("  GUID 0xd068 in", name, "VA=0x%x" % (sva + 0xd068 - raw))
# dump .data window around GUID
gva = None
for name, sva, vsize, raw, rsize in secs:
    if raw <= 0xd068 < raw + rsize:
        gva = sva + 0xd068 - raw
print("GUID VA=0x%x" % gva)
start = gva - 0x100
o = va2off(secs, start)
print("bytes around GUID VA 0x%x:" % start)
for r in range(0, 0x200, 16):
    chunk = d[o + r:o + r + 16]
    print("  %08x  %s" % (start + r, chunk.hex(" ")))
# find qwords in .data pointing into .text
text = [s for s in secs if s[0] == ".text"][0]
tmin, tmax = text[1], text[1] + text[2]
print("\nfunction-pointer-ish qwords near GUID:")
for r in range(-0x100, 0x200, 8):
    va = gva + r
    o = va2off(secs, va)
    q = struct.unpack_from("<Q", d, o)[0]
    mark = "  <-- TEXT" if tmin <= q < tmax else ""
    if q:
        print("  +%+#06x VA=0x%x q=0x%016x%s" % (r, va, q, mark))

# which section holds VA used by adrp/add at code sites? find code refs to GUID VA
print("\nUsbConfigDxe globals 0x136e0-0x13800:")
U = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"
ud, usecs = loads(U)
o = va2off(usecs, 0x136e0)
for r in range(0, 0x130, 16):
    chunk = ud[o + r:o + r + 16]
    vals = struct.unpack("<QQ", chunk)
    print("  %05x  %s   q0=0x%x q1=0x%x" % (0x136e0 + r, chunk.hex(" "), vals[0], vals[1]))
