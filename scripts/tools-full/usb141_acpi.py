#!/usr/bin/env python3
"""Inspect AcpiTableDxe around the EB97088E InstallMultipleProtocolInterfaces call,
and scan stock fv_dump for the GUID."""
import os
import re
import struct
import subprocess

def gb(s):
    q = s.split("-")
    return struct.pack("<IHH", int(q[0], 16), int(q[1], 16), int(q[2], 16)) + bytes.fromhex(q[3] + q[4])

PAT = gb("EB97088E-CFDF-49C6-BE4B-D906A5B20E86")
EFI = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/AcpiTableDxe.efi"
print("=== AcpiTableDxe.efi disasm around 0x2400-0x2560 ===")
out = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", EFI], capture_output=True, text=True).stdout
for ln in out.splitlines():
    m = re.match(r"^\s*([0-9a-f]+):", ln)
    if m and 0x2400 <= int(m.group(1), 16) <= 0x2560:
        print(ln)

print()
print("=== stock fv_dump scan for EB97088E ===")
root = "/mnt/d/本地项目-01/_k70port_extract/fv_dump"
if os.path.isdir(root):
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            p = os.path.join(dirpath, fn)
            try:
                data = open(p, "rb").read()
            except OSError:
                continue
            c = data.count(PAT)
            if c:
                print("  %-90s count=%d size=%d" % (p, c, len(data)))
else:
    print("  missing", root)
