#!/usr/bin/env python3
"""k152_restore_mm.py -- restore the MemoryMapLib "USB" row to the exact keys149
state (row present, after PERIPH_SS).  The keys151b experiment removed it and the
restore step was skipped, which is why keys152's SEC/PEI sha came out as
8dcc2185... instead of keys149's cfcfca5e...

Idempotent.  usage: k152_restore_mm.py [check]
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c")
USB_ROW = '  {"USB",                 0x0A600000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},\n'
ANCHOR = '  {"PERIPH_SS",           0x08800000, 0x00100000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},\n'

s = P.read_text(encoding="utf-8")
rows = sum(1 for ln in s.splitlines() if ln.lstrip().startswith("{"))
has_usb = "0x0A600000" in s
print("MemoryMapLib.c: rows=%d usb_row=%s" % (rows, has_usb))

if len(sys.argv) > 1 and sys.argv[1] == "check":
    sys.exit(0 if has_usb else 1)

if has_usb:
    print("restore: already present")
    sys.exit(0)

if ANCHOR not in s:
    print("restore: FATAL PERIPH_SS anchor not found")
    sys.exit(1)

s = s.replace(ANCHOR, ANCHOR + USB_ROW, 1)
P.write_text(s, encoding="utf-8")
rows = sum(1 for ln in s.splitlines() if ln.lstrip().startswith("{"))
print("restore: USB row inserted after PERIPH_SS; rows now %d" % rows)
