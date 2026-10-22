#!/usr/bin/env python3
"""Map protocol GUID occurrences per FV module, using FVMAIN.inf EFI_FILE_NAME list."""
import os
import re
import struct

BV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV"
GUIDS = {
    "B0760469-970C-487A-A4B5-28DB7B45CEF1": "ChipInfo",
    "FA5F306B-F47D-4AC4-A47D-882F8204EC30": "SPMI",
    "F4E5C7D0-D239-47CB-AACD-7F66EF763238": "SMEM",
    "157A5C45-21B2-43C5-BA7C-822FEE5FE599": "PlatformInfo",
    "EB97088E-CFDF-49C6-BE4B-D906A5B20E86": "EB97088E(unknown)",
    "E722B03F-B250-42CE-8EBD-5BD51812D037": "E722B03F(UsbInitDxe-dep)",
    "4684800A-2755-4EDC-B443-7F8CEB3239D3": "PmicVersion",
}


def gb(s):
    q = s.split("-")
    return struct.pack("<IHH", int(q[0], 16), int(q[1], 16), int(q[2], 16)) + bytes.fromhex(q[3] + q[4])


pats = {k: gb(k) for k in GUIDS}
names = {}
for ln in open(os.path.join(BV, "Guid.xref"), errors="replace"):
    p = ln.split()
    if len(p) >= 2:
        names[p[0].upper()] = p[1]

entries = []
for ln in open(os.path.join(BV, "FVMAIN.inf"), errors="replace"):
    m = re.search(r"EFI_FILE_NAME\s*=\s*(\S+)", ln)
    if m:
        entries.append(m.group(1))

print("FV modules: %d" % len(entries))
print()
hits_by_guid = {k: [] for k in GUIDS}
for path in entries:
    ffs = path
    if not os.path.exists(ffs):
        print("  MISSING", ffs)
        continue
    data = open(ffs, "rb").read()
    fg = "%08X-%04X-%04X-%s-%s" % (*struct.unpack_from("<IHH", data, 0), data[8:10].hex().upper(), data[10:16].hex().upper())
    mod = names.get(fg, "?")
    found = []
    for k, pat in pats.items():
        c = data.count(pat)
        if c:
            found.append("%s x%d" % (GUIDS[k], c))
            hits_by_guid[k].append((mod, c))
    if found:
        print("  %-34s %-6s %s" % (mod, "0x%x" % len(data), ", ".join(found)))

print()
print("=== producers/consumers summary ===")
for k, lst in hits_by_guid.items():
    if lst:
        print("  %-26s -> %s" % (GUIDS[k], ", ".join("%s x%d" % t for t in lst)))
    else:
        print("  %-26s -> NONE" % GUIDS[k])
