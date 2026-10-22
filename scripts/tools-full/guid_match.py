#!/usr/bin/env python3
"""Scan a PE for GUIDs declared in .dec files, print names found."""
import os
import re
import struct
import sys

DEC_DIRS = ["/root/k70/uefi/Mu_Basecore", "/root/k70/uefi/Silicon", "/root/k70/uefi/QcomPkg",
            "/root/k70/uefi/Platforms"]
LINE = re.compile(
    r"^\s*(\w+)\s*=\s*\{?\s*"
    r"0x([0-9a-fA-F]{8})\s*,\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*,\s*"
    r"\{?\s*0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*"
    r"0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})\s*,\s*"
    r"0x([0-9a-fA-F]{2})\s*,\s*0x([0-9a-fA-F]{2})")


def load_guids():
    out = []
    for root in DEC_DIRS:
        if not os.path.isdir(root):
            continue
        for dp, dn, fn in os.walk(root):
            if "/Build" in dp:
                continue
            for f in fn:
                if not (f.endswith(".dec") or f.endswith(".dsc.inc") or f.endswith(".inc")):
                    continue
                try:
                    for line in open(os.path.join(dp, f), errors="ignore"):
                        m = LINE.match(line)
                        if not m:
                            continue
                        a = int(m.group(2), 16)
                        b = int(m.group(3), 16)
                        c = int(m.group(4), 16)
                        tail = bytes(int(m.group(i), 16) for i in range(5, 13))
                        out.append((m.group(1), struct.pack("<IHH", a, b, c) + tail,
                                    "%08X-%04X-%04X-%s-%s" % (a, b, c, tail[:2].hex().upper(), tail[2:].hex().upper())))
                except Exception:
                    pass
    return out


def main(path):
    guids = load_guids()
    data = open(path, "rb").read()
    seen = set()
    hits = []
    for name, pat, s in guids:
        if s in seen:
            continue
        if pat in data:
            seen.add(s)
            offs = []
            i = data.find(pat)
            while i >= 0 and len(offs) < 3:
                offs.append("0x%x" % i)
                i = data.find(pat, i + 1)
            hits.append((s, name, offs))
    hits.sort()
    print("=== %s : %d declared GUIDs matched ===" % (os.path.basename(path), len(hits)))
    for s, name, offs in hits:
        print("  %s  %-52s %s" % (s, name, ",".join(offs)))


if __name__ == "__main__":
    main(sys.argv[1])
