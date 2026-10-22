#!/usr/bin/env python3
"""usb146_dump.py -- dump UsbConfigDxe disassembly for the IOMMU-related
ranges, plus raw bytes at the patch sites, from both the Binaries copy and the
keys145 FV copy. Output goes to _tools/usb146_dump.log for the report."""
import re
import struct
import subprocess
import uuid

UCFG = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"
FVF = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
LINE = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(.+)$")


def dis(path):
    out = subprocess.run(["llvm-objdump", "-d", path], capture_output=True, text=True).stdout
    ins = []
    for ln in out.splitlines():
        m = LINE.match(ln)
        if not m:
            continue
        parts = [p for p in m.group(3).split("\t") if p.strip()]
        mn = parts[0].strip() if parts else ""
        ops = ",".join(p.strip() for p in parts[1:]) if len(parts) > 1 else ""
        ins.append((int(m.group(1), 16), m.group(2), mn, ops))
    return ins


def fv_usbconfig():
    fv = open(FVF, "rb").read()
    hdr = fv.find(b"_FVH", 0, 0x1000)
    base = hdr - 0x28
    off = base + struct.unpack_from("<H", fv, base + 0x30)[0]
    end = min(len(fv), base + struct.unpack_from("<Q", fv, base + 0x20)[0])
    while off + 0x18 <= end:
        ftype = fv[off + 0x12]
        size = fv[off + 0x14] | (fv[off + 0x15] << 8) | (fv[off + 0x16] << 16)
        if size < 0x18 or ftype == 0xFF:
            break
        guid = str(uuid.UUID(bytes_le=bytes(fv[off:off + 16])))
        if guid.startswith("cd823a4d"):
            p = off + 0x18
            while p + 4 <= off + size:
                ss = fv[p] | (fv[p + 1] << 8) | (fv[p + 2] << 16)
                st = fv[p + 3]
                if ss < 4:
                    break
                if st == 0x10 and fv[p + 4:p + 6] == b"MZ":
                    return fv[p + 4:p + ss]
                p = (p + ss + 3) & ~3
        off = (off + size + 7) & ~7
    return None


ins = dis(UCFG)
d = open(UCFG, "rb").read()
print("== Binaries UsbConfigDxe.patched.efi 0x3f68-0x41d0")
for a, raw, mn, ops in ins:
    if 0x3f68 <= a <= 0x41d0:
        print("  %08x  %s  %-8s %s" % (a, raw, mn, ops))
print("\n== Binaries 0x8860-0x8990")
for a, raw, mn, ops in ins:
    if 0x8860 <= a <= 0x8990:
        print("  %08x  %s  %-8s %s" % (a, raw, mn, ops))
print("\n== Binaries 0x5360-0x5400")
for a, raw, mn, ops in ins:
    if 0x5360 <= a <= 0x5400:
        print("  %08x  %s  %-8s %s" % (a, raw, mn, ops))
print("\npatch-site bytes (Binaries pristine):")
for off in (0x3FA8, 0x3FAC, 0x3FE8, 0x3FEC, 0x3FF0, 0x4000, 0x53CC):
    print("  0x%05x %s" % (off, d[off:off + 8].hex(" ")))

uc = fv_usbconfig()
print("\nFV (keys145) UsbConfigDxe len", len(uc) if uc else None)
if uc:
    for off in (0x3FA8, 0x3FAC, 0x3FE8, 0x3FEC, 0x3FF0, 0x4000, 0x53CC):
        print("  0x%05x %s" % (off, uc[off:off + 8].hex(" ")))
    open("/tmp/ucfg_keys145.efi", "wb").write(uc)
    print("\n== keys145 FV copy 0x3f80-0x4010")
    ins2 = dis("/tmp/ucfg_keys145.efi")
    for a, raw, mn, ops in ins2:
        if 0x3f80 <= a <= 0x4010:
            print("  %08x  %s  %-8s %s" % (a, raw, mn, ops))
