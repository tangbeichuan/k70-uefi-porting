#!/usr/bin/env python3
"""k152_tail3.py <img...> -- locate the exact appended vermeer.dtb (808716 B) and
compare against the dtb file on disk."""
import hashlib
import sys

DTB = open("/root/k70/uefi/Resources/DTBs/vermeer.dtb", "rb").read()
print("dtb file: len=%d sha=%s" % (len(DTB), hashlib.sha256(DTB).hexdigest()))

for p in sys.argv[1:]:
    d = open(p, "rb").read()
    i = d.find(DTB)
    print("%-30s dtb_off=%s found=%s" % (p.split("/")[-1], hex(i) if i >= 0 else "-", i >= 0))
    if i < 0:
        # find longest matching suffix/prefix to see where it diverges
        n = 0
        for j in range(len(d) - len(DTB), len(d)):
            if d[j:j + 64] == DTB[:64]:
                n = j
                break
        print("   prefix64 match at", hex(n) if n else "none")
