#!/usr/bin/env python3
"""k152_tail2.py -- identical tail check for packed boot images."""
import hashlib
import sys

TAIL = 808716

for p in sys.argv[1:]:
    d = open(p, "rb").read()
    t = d[-TAIL:]
    print("%-30s tail_sha=%s head4=%s size=%d" % (p.split("/")[-1], hashlib.sha256(t).hexdigest(), t[:4].hex(), len(d)))
