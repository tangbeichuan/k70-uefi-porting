#!/usr/bin/env python3
"""keys147: identify protocol GUID at UsbfnDwc3Dxe .data 0x16098, and map FV
producers/consumers of the device-mode USB protocols."""
import struct
import sys
import uuid

sys.path.insert(0, "/mnt/d/本地项目-01/_tools")
import guid_match

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
B = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers"


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def gstr(b, o):
    return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))


def fv_modules():
    fv = open(FV, "rb").read()
    hdr = fv.find(b"_FVH", 0, 0x1000)
    base = hdr - 0x28
    off = base + u16(fv, base + 0x30)
    end = min(len(fv), base + u64(fv, base + 0x20))
    mods = []
    while off + 0x18 <= end:
        ftype = fv[off + 0x12]
        size = fv[off + 0x14] | (fv[off + 0x15] << 8) | (fv[off + 0x16] << 16)
        if size < 0x18 or ftype == 0xFF:
            break
        guid = gstr(fv, off)
        body, b_end = off + 0x18, off + size
        name = None
        p = body
        while p + 4 <= b_end:
            ssize = fv[p] | (fv[p + 1] << 8) | (fv[p + 2] << 16)
            stype = fv[p + 3]
            if ssize < 4:
                break
            if stype == 0x15:
                name = fv[p + 4:p + ssize].decode("utf-16-le", "ignore").rstrip("\x00")
                break
            p = (p + ssize + 3) & ~3
        mods.append((off, off + size, guid, name or guid))
        off = (off + size + 7) & ~7
    return fv, mods


def who(mods, pos):
    for s, e, g, n in mods:
        if s <= pos < e:
            return n
    return "?"


def rename(name):
    # FFS UI name is like "UsbConfigDxe" (module name)
    return name


def main():
    guid_match.load_guids()
    fv, mods = fv_modules()

    # 1) UsbfnDwc3Dxe .data GUID table dump 0x16040..0x16160
    d = open(B + "/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi", "rb").read()
    print("== UsbfnDwc3Dxe .data GUIDs 0x16040-0x16160 ==")
    names = {}
    for nm, pat, s in guid_match.load_guids():
        names.setdefault(pat, nm)
    for o in range(0x16040, 0x16160, 0x10):
        b = d[o:o + 16]
        print("  0x%05x %s  %s" % (o, gstr(d, o), names.get(b, "")))
    g160 = d[0x16098:0x16098 + 16]
    print("\nGUID@0x16098 = %s  name=%s" % (gstr(d, 0x16098), names.get(g160, "?")))
    print("GUID@0x16098 bytes_le =", g160.hex())

    # 2) UsbDeviceDxe .data GUID table
    e = open(B + "/UsbDeviceDxe/UsbDeviceDxe.efi", "rb").read()
    print("\n== UsbDeviceDxe .data GUIDs 0xa040-0xa0f0 ==")
    for o in range(0xa040, 0xa0f0, 0x10):
        b = e[o:o + 16]
        print("  0x%05x %s  %s" % (o, gstr(e, o), names.get(b, "")))

    # 3) producers in FV for key GUIDs
    keys = {
        "16098(UsbfnDwc3 wants)": g160,
        "gEfiUsbDeviceProtocol D9D9CE48": uuid.UUID("D9D9CE48-44B8-4F49-8E3E-2A3B927DC6C1").bytes_le,
        "gEfiUsbFunctionIo 32D2963A": uuid.UUID("32D2963A-FE5D-4F30-B633-6E5DC55803CC").bytes_le,
        "gQcomUsbConfig E722B03F": uuid.UUID("E722B03F-B250-42CE-8EBD-5BD51812D037").bytes_le,
        "gEfiUsbMsd C8591FAF": uuid.UUID("C8591FAF-DBCC-479E-9EF2-FD085BC37BC7").bytes_le,
        "gEfiDriverBinding 18A031AB": uuid.UUID("18A031AB-B443-4D1A-A5C0-0C09261E9F71").bytes_le,
    }
    print("\n== FV occurrences by module ==")
    for label, pat in keys.items():
        hits = []
        pos = 0
        while True:
            pos = fv.find(pat, pos)
            if pos < 0:
                break
            hits.append((pos, who(mods, pos)))
            pos += 1
        from collections import Counter
        c = Counter(n for _, n in hits)
        print("  %-40s total=%d  %s" % (label, len(hits), dict(c)))


if __name__ == "__main__":
    main()
