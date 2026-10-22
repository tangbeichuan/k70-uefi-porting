#!/usr/bin/env python3
"""patch_gcc155.py -- keys155: add the GCC register region to the PEI memory map.

GCC base 0x00100000, size 0x00200000 (lead: same row that booted in keys93).
Appends after the USB row.  Idempotent.  Modes:
  add      (default)  insert the row if missing
  check               report presence only
  restore             remove the row (back to pre-keys155) and touch the file so
                      the next build really recompiles Sec/PEI
"""
import pathlib
import re
import subprocess
import sys

F = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c")
BAK = pathlib.Path("/tmp/MemoryMapLib.c.k155bak")
ROW = '  {"GCC",                 0x00100000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
PAT = re.compile(r'^\s*\{\s*"GCC"\s*,\s*0x0*100000\b.*\},?\s*$', re.M)

mode = sys.argv[1] if len(sys.argv) > 1 else "add"
s = F.read_text(encoding="utf-8")
present = bool(PAT.search(s))
print(f"patch_gcc155[{mode}]: GCC row present={present}")

if mode == "check":
    sys.exit(0 if present else 1)

if mode == "add":
    if present:
        print("patch_gcc155: already present")
        sys.exit(0)
    if not BAK.exists():
        BAK.write_text(s, encoding="utf-8")
    anchor = '  {"USB",                 0x0A600000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    if anchor not in s:
        print("patch_gcc155: FATAL USB anchor row not found")
        sys.exit(1)
    s = s.replace(anchor, anchor + "\n" + ROW, 1)
    F.write_text(s, encoding="utf-8")
    print("PATCH_GCC155 OK: GCC row added after USB row")
    sys.exit(0)

if mode == "restore":
    if not present:
        print("patch_gcc155: nothing to restore")
    else:
        s = PAT.sub("", s, count=1)
        s = s.replace("\n\n\n", "\n\n")
        F.write_text(s, encoding="utf-8")
        print("patch_gcc155: GCC row removed")
    # force the next build to recompile Sec/PEI (stale-mtime trap)
    subprocess.run(["touch", str(F)], check=False)
    sys.exit(0)

print("patch_gcc155: unknown mode", mode)
sys.exit(2)
