#!/usr/bin/env python3
"""usb146_refs2.py -- print every UsbConfigDxe instruction referencing the
IOMMU globals (0x768/0x770/0x778/0x780/0x781) with context."""
import re
import subprocess

UCFG = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"
LINE = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(.+)$")

out = subprocess.run(["llvm-objdump", "-d", UCFG], capture_output=True, text=True).stdout
ins = []
for ln in out.splitlines():
    m = LINE.match(ln)
    if not m:
        continue
    parts = m.group(3).split("\t")
    parts = [p for p in parts if p.strip()]
    mn = parts[0].strip() if parts else ""
    ops = ",".join(p.strip() for p in parts[1:]) if len(parts) > 1 else ""
    ins.append((int(m.group(1), 16), mn, ops))

print("parsed", len(ins), "insns")
OFFS = ("#0x768", "#0x770", "#0x778", "#0x780", "#0x781")
for i, (a, mn, ops) in enumerate(ins):
    if any(o in ops for o in OFFS):
        print("\n--- hit at %08x: %s %s" % (a, mn, ops))
        for j in range(max(0, i - 5), min(len(ins), i + 6)):
            mark = ">>" if j == i else "  "
            print("  %s %08x %-8s %s" % (mark, ins[j][0], ins[j][1], ins[j][2]))
