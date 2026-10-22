#!/usr/bin/env python3
"""Scan whole /root/k70 tree for EB97088E GUID bytes; report files and whether the
reference looks like Install (producer) or Locate (consumer) by disassembling .efi hits."""
import os
import re
import struct
import subprocess

G = "EB97088E-CFDF-49C6-BE4B-D906A5B20E86"


def gb(s):
    q = s.split("-")
    return struct.pack("<IHH", int(q[0], 16), int(q[1], 16), int(q[2], 16)) + bytes.fromhex(q[3] + q[4])


PAT = gb(G)
ROOTS = ["/root/k70/uefi", "/root/k70"]
hits = []
for root in ROOTS:
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            p = os.path.join(dirpath, fn)
            try:
                if os.path.getsize(p) > 40 * 1024 * 1024:
                    continue
                with open(p, "rb") as f:
                    data = f.read()
            except OSError:
                continue
            c = data.count(PAT)
            if c:
                hits.append((p, c, len(data)))

seen = set()
print("=== files containing EB97088E ===")
for p, c, sz in sorted(hits):
    print("  %-100s count=%d size=%d" % (p, c, sz))
    seen.add(p)

print()
print("=== classify .efi hits (Install vs Locate) ===")


def pe_sections(data):
    e = struct.unpack_from("<I", data, 0x3C)[0]
    n = struct.unpack_from("<H", data, e + 6)[0]
    opt = struct.unpack_from("<H", data, e + 20)[0]
    base = e + 24 + opt
    secs = []
    for i in range(n):
        o = base + i * 40
        name = data[o:o + 8].rstrip(b"\0").decode("latin1")
        vsize, va, rsize, roff = struct.unpack_from("<IIII", data, o + 8)
        secs.append((name, va, vsize, roff, rsize))
    return secs


for p in sorted(seen):
    if not p.lower().endswith(".efi"):
        continue
    data = open(p, "rb").read()
    secs = pe_sections(data)
    pos = data.find(PAT)
    va = None
    while pos >= 0:
        for name, sva, vsize, roff, rsize in secs:
            if roff <= pos < roff + rsize:
                va = sva + (pos - roff)
                break
        if va:
            break
        pos = data.find(PAT, pos + 1)
    if va is None:
        print("  %-80s GUID not in a section" % os.path.basename(p))
        continue
    out = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", p], capture_output=True, text=True).stdout
    insns = []
    for ln in out.splitlines():
        m = re.match(r"^\s*([0-9a-f]+):\s+(.*)$", ln)
        if m:
            insns.append((int(m.group(1), 16), m.group(2).strip()))
    kinds = []
    for i, (addr, txt) in enumerate(insns):
        m = re.match(r"adrp\s+(x\d+),\s+0x([0-9a-f]+)", txt)
        if not m:
            continue
        reg, page = m.group(1), int(m.group(2), 16)
        for j in range(i + 1, min(i + 6, len(insns))):
            t2 = insns[j][1]
            m2 = re.match(r"add\s+%s,\s+%s,\s+#0x([0-9a-f]+)" % (reg, reg), t2)
            if not m2:
                continue
            if page + int(m2.group(1), 16) == va:
                # scan following 20 instructions for BS method offsets
                for k in range(j + 1, min(j + 24, len(insns))):
                    t3 = insns[k][1]
                    m3 = re.search(r"ldr\s+x\d+,\s+\[x\d+,\s+#0x([0-9a-f]+)\]", t3)
                    if m3:
                        off = int(m3.group(1), 16)
                        label = {0x80: "InstallProtocolInterface", 0x148: "InstallMultipleProtocolInterfaces",
                                 0x140: "LocateProtocol", 0x98: "HandleProtocol", 0xa8: "RegisterProtocolNotify",
                                 0x138: "LocateHandleBuffer", 0x118: "OpenProtocol"}.get(off, "BS+0x%x" % off)
                        if label.startswith("BS+"):
                            continue
                        kinds.append("%s@0x%x" % (label, addr))
                        break
            break
    print("  %-60s VA=0x%-6x %s" % (os.path.basename(p), va, ", ".join(kinds) or "no BS call found"))
