#!/usr/bin/env python3
"""patch_peimap151.py -- optionally remove the USB IO region row from MemoryMapLib.c.

usage:
  patch_peimap151.py check
  patch_peimap151.py remove     # delete the {"USB", 0x0A600000, ...} row (idempotent)
  patch_peimap151.py restore <backupfile>

The row is:
  {"USB", 0x0A600000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
"""
import re, shutil, sys

SRC = "/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c"
BAK = "/tmp/MemoryMapLib.c.k151bak"
PAT = re.compile(r'^\s*\{\s*"USB"\s*,\s*0x0?A600000\b.*\},?\s*$', re.IGNORECASE)


def lines():
    with open(SRC, "r", encoding="utf-8", errors="replace") as f:
        return f.readlines()


def check():
    hits = [(i + 1, l.rstrip()) for i, l in enumerate(lines()) if PAT.match(l)]
    print("USB rows in MemoryMapLib.c: %d" % len(hits))
    for n, l in hits:
        print("  line %d: %s" % (n, l))
    return len(hits)


def backup():
    shutil.copy2(SRC, BAK)
    print("backup ->", BAK)


def remove():
    ls = lines()
    keep, removed = [], []
    for i, l in enumerate(ls):
        if PAT.match(l):
            removed.append((i + 1, l.rstrip()))
        else:
            keep.append(l)
    if not removed:
        print("PATCH_PEIMAP151: already absent (0 rows) -> OK")
        return
    if not BAK:
        pass
    with open(SRC, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(keep)
    print("PATCH_PEIMAP151: removed %d row(s)" % len(removed))
    for n, l in removed:
        print("  line %d: %s" % (n, l))
    check()


def restore(path):
    shutil.copy2(path, SRC)
    print("restored from", path)
    check()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        check()
    elif cmd == "backup":
        backup()
    elif cmd == "remove":
        if not __import__("os").path.exists(BAK):
            backup()
        remove()
    elif cmd == "restore":
        restore(sys.argv[2] if len(sys.argv) > 2 else BAK)
    else:
        print("unknown command", cmd)
        sys.exit(2)
