#!/usr/bin/env python3
"""Decode an EFI DEPEX file and show opcodes + GUIDs (with names from .dec files)."""
import struct
import sys
import os
import re

NAMES = {}
DEC_ROOTS = ["/root/k70/uefi", "/root/k70/uefi/Mu_Basecore"]


def load_names():
    pat = re.compile(r"^\s*(\w+)\s*=\s*\{?\s*0x([0-9a-fA-F]{8})\s*,\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})")
    for root in DEC_ROOTS:
        for dp, dn, fn in os.walk(root):
            if "/Build" in dp:
                continue
            for f in fn:
                if not f.endswith(".dec") and not f.endswith(".dsc") and not f.endswith(".inc"):
                    continue
                p = os.path.join(dp, f)
                try:
                    for line in open(p, "r", errors="ignore"):
                        m = pat.match(line)
                        if m:
                            key = (int(m.group(2), 16), int(m.group(3), 16), int(m.group(4), 16))
                            NAMES.setdefault(key, m.group(1))
                except Exception:
                    pass


def gstr(b):
    a, bb, c = struct.unpack("<IHH", b[:8])
    return "%08X-%04X-%04X-%s-%s" % (a, bb, c, b[8:10].hex().upper(), b[10:16].hex().upper()), (a, bb, c)


def main(path):
    load_names()
    d = open(path, "rb").read()
    i = 0
    print("=== %s (%d bytes) ===" % (os.path.basename(path), len(d)))
    while i < len(d):
        op = d[i]
        if op == 0x00:
            print("  BEFORE"); i += 1
        elif op == 0x01:
            print("  AFTER"); i += 1
        elif op == 0x02:
            s, key = gstr(d[i + 1:i + 17])
            name = NAMES.get(key, "?")
            print("  PUSH   %s  %s" % (s, name))
            i += 17
        elif op == 0x03:
            print("  AND"); i += 1
        elif op == 0x04:
            print("  OR"); i += 1
        elif op == 0x05:
            print("  NOT"); i += 1
        elif op == 0x06:
            print("  TRUE"); i += 1
        elif op == 0x07:
            print("  FALSE"); i += 1
        elif op == 0x08:
            print("  END"); i += 1
        elif op == 0x09:
            s, key = gstr(d[i + 1:i + 17])
            print("  SOR    %s  %s" % (s, NAMES.get(key, "?")))
            i += 17
        else:
            print("  ? opcode 0x%02x at %d" % (op, i))
            break


if __name__ == "__main__":
    main(sys.argv[1])
