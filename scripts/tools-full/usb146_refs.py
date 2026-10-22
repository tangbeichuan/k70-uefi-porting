#!/usr/bin/env python3
"""usb146_refs.py -- find adrp/add pairs that materialize strings in
0x12b60..0x12c60 of UsbConfigDxe and print 25 insns of context."""
import re
import sys

ASM = "/tmp/u145.asm"
lines = open(ASM, errors="ignore").read().splitlines()
ins = []
for l in lines:
    m = re.match(r"\s+([0-9a-f]+):\s+([0-9a-f]{8})\s+(\S+)\s*(.*)$", l)
    if m:
        ins.append({"a": int(m.group(1), 16), "w": m.group(2), "op": m.group(3), "args": m.group(4), "raw": l})

idx_by_addr = {i["a"]: k for k, i in enumerate(ins)}
targets = []
for k, i in enumerate(ins):
    if i["op"] == "adrp":
        m = re.search(r"0x([0-9a-f]+)", i["args"])
        if not m:
            continue
        page = int(m.group(1), 16)
        if page not in (0x12000, 0x13000):
            continue
        for j in range(k + 1, min(k + 4, len(ins))):
            m2 = re.search(r"#0x([0-9a-f]+)", ins[j]["args"])
            if ins[j]["op"] == "add" and m2:
                tgt = page + int(m2.group(1), 16)
                if 0x12b60 <= tgt <= 0x12c60:
                    targets.append((k, tgt))
                break

seen = set()
for k, tgt in targets:
    if (tgt) in seen:
        continue
    seen.add(tgt)
    print("=== ref to string 0x%x (insn idx %d, addr 0x%x) ===" % (tgt, k, ins[k]["a"]))
    lo = max(0, k - 30)
    hi = min(len(ins), k + 14)
    for j in range(lo, hi):
        mark = " <== here" if j == k else ""
        print("   ", ins[j]["raw"].strip(), mark)
    print()
