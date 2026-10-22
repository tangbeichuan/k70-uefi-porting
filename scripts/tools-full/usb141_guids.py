#!/usr/bin/env python3
"""Find which prebuilt drivers reference given EFI protocol GUIDs (byte scan of PE/depex)."""
import pathlib
import struct
import sys

ROOTS = [
    pathlib.Path("/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers"),
    pathlib.Path("/root/k70/uefi/Binaries/vermeer/SiliciumPkg"),
    pathlib.Path("/root/k70/uefi/Binaries/vermeer"),
    pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB"),
]

GUIDS = {
    "B0760469": "B0760469-970C-487A-A4B5-28DB7B45CEF1",
    "FA5F306B": "FA5F306B-F47D-4AC4-A47D-882F8204EC30",
    "F4E5C7D0": "F4E5C7D0-D239-47CB-AACD-7F66EF763238",
    "157A5C45": "157A5C45-21B2-43C5-BA7C-822FEE5FE599",
    "EB97088E": "EB97088E-CFDF-49C6-BE4B-D906A5B20E86",
    "4684800A": "4684800A-2755-4EDC-B443-7F8CEB3239D3",
    "AE37B942": "AE37B942-457F-4C91-A196-D9669FD347A3",
}


def guid_bytes(s):
    p = s.split("-")
    d1, d2, d3 = int(p[0], 16), int(p[1], 16), int(p[2], 16)
    b = struct.pack("<IHH", d1, d2, d3) + bytes.fromhex(p[3] + p[4])
    return b


PATTERNS = {k: guid_bytes(v) for k, v in GUIDS.items()}

seen = {}
for root in ROOTS:
    if not root.exists():
        continue
    for f in root.rglob("*"):
        if not f.is_file() or f.suffix.lower() not in (".efi", ".depex", ".ffs", ".fv", ".pe32"):
            continue
        try:
            data = f.read_bytes()
        except OSError:
            continue
        for key, pat in PATTERNS.items():
            if pat in data:
                seen.setdefault(key, []).append(str(f))

for key in GUIDS:
    hits = seen.get(key, [])
    print("=== %s  (%s)  hits=%d" % (key, GUIDS[key], len(hits)))
    for h in hits[:40]:
        print("   " + h)
    print()
