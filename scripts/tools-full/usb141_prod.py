#!/usr/bin/env python3
"""Find producers of EB97088E-CFDF-49C6-BE4B-D906A5B20E86 and 4684800A... anywhere."""
import pathlib
import struct

GUIDS = {
    "EB97088E (unknown, UsbConfigDxe depex)": "EB97088E-CFDF-49C6-BE4B-D906A5B20E86",
    "4684800A (gQcomPmicVersionProtocolGuid)": "4684800A-2755-4EDC-B443-7F8CEB3239D3",
    "FA5F306B (SPMI?)": "FA5F306B-F47D-4AC4-A47D-882F8204EC30",
}


def gb(s):
    p = s.split("-")
    return struct.pack("<IHH", int(p[0], 16), int(p[1], 16), int(p[2], 16)) + bytes.fromhex(p[3] + p[4])


PAT = {k: gb(v) for k, v in GUIDS.items()}
ROOTS = [
    pathlib.Path("/root/k70/uefi/Binaries"),
    pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"),
    pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/fv_dump"),
    pathlib.Path("/mnt/d/本地项目-01/K70-UEFI-build"),
]
EXTS = (".efi", ".depex", ".ffs", ".fv", ".bin", ".img", ".pe32", ".fd")

for label, pat in PAT.items():
    print("=== %s ===" % label)
    hits = []
    for root in ROOTS:
        items = [root] if root.is_file() else [f for f in root.rglob("*") if f.is_file()]
        for f in items:
            if f.is_file() and f.suffix.lower() not in EXTS:
                continue
            try:
                if f.stat().st_size > 64 * 1024 * 1024:
                    continue
                data = f.read_bytes()
            except OSError:
                continue
            if pat in data:
                hits.append((str(f), data.count(pat)))
    for h, n in hits[:60]:
        print("   x%-3d %s" % (n, h))
    if not hits:
        print("   (no hits)")
    print()
