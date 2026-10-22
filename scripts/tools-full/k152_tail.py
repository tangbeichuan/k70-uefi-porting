#!/usr/bin/env python3
"""k152_tail.py <img...> -- report embedded DTB offset/sha for each image."""
import hashlib
import sys

MAGIC = b"\xd0\x0d\xfe\xed"


def main():
    for p in sys.argv[1:]:
        d = open(p, "rb").read()
        i = d.find(MAGIC)
        if i < 0:
            print(p, "DTB magic not found")
            continue
        t = d[i:]
        print("%-46s dtb_off=0x%-6x dtb_len=%-7d dtb_sha=%s" %
              (p.split("/")[-1], i, len(t), hashlib.sha256(t).hexdigest()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
