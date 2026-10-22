#!/usr/bin/env python3
"""
usb145_elr2.py -- the exception dump gives ELR = 0x...E0FF0 with FAR = 0x8.
If the faulting code lives in an FV driver loaded at a page-aligned base, the
faulting instruction sits at image RVA == 0xFF0 (mod 0x1000).  Scan every EFI
module built for this platform and print the instructions located at
RVA & 0xFFF == 0xFF0, highlighting memory accesses, so we can identify which
module can fault with FAR = 0x8.

usage: python3 usb145_elr2.py <dir-with-efi-files> [<dir> ...]
"""
import os
import re
import subprocess
import sys

LOAD_RE = re.compile(r"^(ldr|ldurb|ldurh|ldur|ldp|ldrsb|ldrsh|ldrsw|ldrb|ldrh|ldar|ldaxr)\b")


def disasm(path):
    out = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", path],
                         capture_output=True, text=True).stdout
    ins = []
    for L in out.split("\n"):
        m = re.match(r"\s*([0-9a-f]+):\s+(\S+)\s*(.*)", L)
        if m:
            ins.append((int(m.group(1), 16), m.group(2), m.group(3).strip()))
    return ins


def main(dirs):
    hits = []
    files = []
    for d in dirs:
        for dirpath, _dirs, fns in os.walk(d):
            for fn in fns:
                if fn.lower().endswith(".efi"):
                    files.append(os.path.join(dirpath, fn))
    files.sort()
    for f in files:
        try:
            ins = disasm(f)
        except Exception:
            continue
        if not ins:
            continue
        for i, (a, op, arg) in enumerate(ins):
            if a & 0xFFF != 0xFF0:
                continue
            if not LOAD_RE.match(op):
                continue
            hits.append((os.path.basename(f), a, op, arg, ins[max(0, i - 6):i + 4]))
    print("files scanned: %d, load-hits at RVA&0xFFF==0xFF0: %d" % (len(files), len(hits)))
    for name, a, op, arg, ctx in hits:
        print("\n### %s @RVA 0x%06x : %s %s" % (name, a, op, arg))
        for (ca, cop, carg) in ctx:
            mark = ">>" if ca == a else "  "
            print("   %s %06x  %-8s %s" % (mark, ca, cop, carg))


if __name__ == "__main__":
    main(sys.argv[1:] or ["/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64"])
