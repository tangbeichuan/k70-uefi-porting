#!/usr/bin/env python3
"""Decode EFI_DEPEX blobs for the USB stack modules and compare .efi vs .patched.efi."""
import hashlib
import pathlib
import struct

BIN = pathlib.Path("/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers")

MODS = [
    "UsbConfigDxe", "UsbInitDxe", "UsbMsdDxe", "UsbfnDwc3Dxe", "UsbDeviceDxe",
    "UsbPwrCtrlDxe", "UsbBusDxe",
]

OPS = {0x00: "BEFORE", 0x01: "AFTER", 0x02: "PUSH", 0x03: "AND", 0x04: "OR",
       0x05: "NOT", 0x06: "TRUE", 0x07: "FALSE", 0x08: "END", 0x09: "SOR"}


def decode(data):
    i = 0
    out = []
    while i < len(data):
        op = data[i]
        i += 1
        if op in (0x00, 0x01, 0x02):
            if op == 0x02 and i + 16 <= len(data):
                g = data[i:i + 16]
                d1, d2, d3 = struct.unpack("<IHH", g[:8])
                guid = "%08X-%04X-%04X-%s-%s" % (
                    d1, d2, d3, g[8:10].hex().upper(), g[10:16].hex().upper())
                out.append(("PUSH", guid))
                i += 16
            else:
                out.append((OPS[op], ""))
        else:
            out.append((OPS.get(op, "OP%02X" % op), ""))
        if op == 0x08:
            break
    return out


for name in MODS:
    d = BIN / name
    if not d.is_dir():
        continue
    print("=== %s ===" % name)
    depexes = sorted(d.glob("*.depex"))
    if not depexes:
        print("  (no .depex file)")
    for f in depexes:
        data = f.read_bytes()
        print("  %s (%d bytes):" % (f.name, len(data)))
        for op, arg in decode(data):
            print("    %-6s %s" % (op, arg))
    inf = d / (name + ".inf")
    if inf.is_file():
        txt = inf.read_text(errors="replace")
        for ln in txt.splitlines():
            if any(k in ln for k in ("PE32|", "[Depex]", "DXE_DEPEX|", "FILE_GUID", "BASE_NAME")):
                print("  INF: " + ln.strip())
    efis = sorted(d.glob("*.efi"))
    for e in efis:
        print("  EFI %-24s %9d %s" % (e.name, e.stat().st_size,
                                       hashlib.sha256(e.read_bytes()).hexdigest()[:32]))
    if len(efis) == 2:
        a, b = efis[0].read_bytes(), efis[1].read_bytes()
        n = min(len(a), len(b))
        diffs = [i for i in range(n) if a[i] != b[i]]
        print("  diff bytes: %d%s" % (len(diffs), (" first=0x%x" % diffs[0]) if diffs else ""))
        for i in diffs[:16]:
            print("    0x%06x: %02x -> %02x" % (i, a[i], b[i]))
    print()
