#!/usr/bin/env python3
"""cf146c.py -- raw scan of a .fd / .img for UsbConfigDxe hardening bytes."""
import sys

PATS = [
    ("ORIGINAL b6f80208 (tbz x8,#0x3f)", "b6f80208"),
    ("HARDENED 36f80208 (tbz w8,#0x1f)", "36f80208"),
    ("HARDENED 280100b4 (keys145 cbz)", "280100b4"),
    ("site f9400508 (ldr x8,[x8,#8])", "f9400508"),
    ("gIommu adrp+ldr 0x90000088f943b508", "90000088f943b508"),
    ("UsbConfigDxe name", "UsbConfigDxe"),
    ("clock guid 241AFAE6 (le)", "e6fa1a248f5f6c4fa7eac28eab79c3e5"),
    ("HALIOMMU guid 9A00771F (le)", "1f77009ad436d54d8916c48ed9b16b86"),
]

for path in sys.argv[1:]:
    d = open(path, "rb").read()
    print("=" * 72)
    print(path, "size", len(d))
    for name, pat in PATS:
        p = bytes.fromhex(pat)
        n = d.count(p)
        first = d.find(p)
        print("  %-42s count=%-3d first=%s" % (name, n, hex(first) if first >= 0 else "-"))
