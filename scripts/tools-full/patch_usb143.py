#!/usr/bin/env python3
"""keys143: bring the vendor HAL IOMMU producer back into the FV and harden
UsbConfigDxe against a missing protocol.

Why
---
UsbConfigDxe crash at PC+0x3FF0 (FAR=0x8) on keys142:
  LocateProtocol(gHalIommuProtocolGuid=54B6D3B4-5D33-4F91-8600-6C41D5DEB19A)
  returned EFI_NOT_FOUND, but the compiled check is `tbz x8,#0x3f` on a value
  that was just truncated to W (`mov w8,w0` -> w8 zero-extended, bit63 == 0),
  so the error branch is dead code and the success path dereferences the NULL
  global gIommu ([0x13768]+0x8).  The vendor error path itself is fine
  (clears the global, logs "Failed to open HAL IOMMU protocol", continues), so
  the IOMMU is clearly meant to be optional.  The real problem is only that
  our FV has no HALIOMMU producer (keys70 hard-dropped it).

What this patch does (all idempotent)
-------------------------------------
1) Include/DXE.inc   : un-comment `# [keys70-hard] INF .../HALIOMMUDxe.inf`
                       (DXE.inc is the authoritative FV placement list).
2) Include/APRIORI.inc: un-comment the same HALIOMMU line, and insert
                       `INF vermeerPkg/Drivers/VermeerDtbExtnDxe/...` right
                       before it.  HALIOMMU parses /soc/iort through the
                       DTBExtn protocol, and an APRIORI module dispatches
                       before any non-APRIORI module -- without this the
                       provider would not be up yet.
3) Binaries/.../UsbConfigDxe/UsbConfigDxe.patched.efi: patch the broken
   EFI_ERROR test at file offset 0x3FA8
       0xB6F80208  tbz x8,#0x3f,0x3fe8     (dead: x8 bit63 is always 0)
    -> 0x36F80208  tbz w8,#0x1f,0x3fe8     (== EFI_ERROR() on the W value)
   A backup is kept as UsbConfigDxe.patched.efi.bak143 and run143.sh restores
   it after the build.
"""
import os
import re
import shutil
import struct
import sys

PKG = "/root/k70/uefi/Platforms/Xiaomi/vermeerPkg"
DXE = PKG + "/Include/DXE.inc"
APRIORI = PKG + "/Include/APRIORI.inc"
INF_HAL = "INF Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.inf"
INF_PROV = "INF vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf"

UCFG = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"
UCFG_BAK = UCFG + ".bak143"
PATCH_OFF = 0x3FA8
OLD = 0xB6F80208
NEW = 0x36F80208

_fail = []


def die(msg):
    _fail.append(msg)
    print("PATCH_USB143 FATAL: " + msg)


def read_lines(path):
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
        return f.read().split("\n")


def write_lines(path, lines):
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write("\n".join(lines))


def uncomment_hard(lines, needle, where):
    """Turn '# [keysNN-hard]   INF ...' into '  INF ...'."""
    done = False
    for i, ln in enumerate(lines):
        s = ln.strip()
        if not (s.startswith("#") and needle in s):
            continue
        m = re.match(r"^(\s*)#\s*\[keys?\d*-hard\]\s*(INF\s+.*)$", ln)
        if not m:
            die("%s: unexpected commented form: %r" % (where, ln))
            return False
        lines[i] = m.group(1) + "  " + m.group(2)
        done = True
        break
    if not done:
        if any(ln.strip().startswith("INF ") and needle in ln for ln in lines):
            print("  %s: already active" % where)
        else:
            die("%s: neither active nor keys70-hard line for %s" % (where, needle))
    return done


def patch_dxe():
    lines = read_lines(DXE)
    uncomment_hard(lines, "HALIOMMUDxe", "DXE.inc")
    write_lines(DXE, lines)


def patch_apriori():
    lines = read_lines(APRIORI)
    # locate the HALIOMMU line (active or commented)
    idx = -1
    for i, ln in enumerate(lines):
        if "HALIOMMUDxe" in ln:
            idx = i
            break
    if idx < 0:
        die("APRIORI.inc: HALIOMMUDxe line not found")
        return

    uncomment_hard(lines, "HALIOMMUDxe", "APRIORI.inc")

    # find it again after uncommenting
    idx = next(i for i, ln in enumerate(lines) if "HALIOMMUDxe" in ln)
    if any("VermeerDtbExtnDxe" in ln for ln in lines):
        print("  APRIORI.inc: VermeerDtbExtnDxe already present")
    else:
        indent = re.match(r"^(\s*)", lines[idx]).group(1)
        lines.insert(idx, indent + INF_PROV)
        print("  APRIORI.inc: inserted VermeerDtbExtnDxe before HALIOMMUDxe (line %d)" % (idx + 1))
    write_lines(APRIORI, lines)

    # sanity: provider must precede HALIOMMU
    pi = next(i for i, ln in enumerate(lines) if "VermeerDtbExtnDxe" in ln)
    hi = next(i for i, ln in enumerate(lines) if "HALIOMMUDxe" in ln)
    if pi > hi:
        die("APRIORI.inc: provider (%d) is after HALIOMMU (%d)" % (pi + 1, hi + 1))
    else:
        print("  APRIORI.inc: order provider line %d < HALIOMMU line %d OK" % (pi + 1, hi + 1))


def patch_ucfg():
    if not os.path.exists(UCFG):
        die("UsbConfigDxe.patched.efi not found")
        return
    data = bytearray(open(UCFG, "rb").read())
    cur = struct.unpack("<I", data[PATCH_OFF:PATCH_OFF + 4])[0]
    if cur == OLD:
        struct.pack_into("<I", data, PATCH_OFF, NEW)
        open(UCFG, "wb").write(bytes(data))
        print("  UsbConfigDxe.patched.efi: 0x%08X -> 0x%08X (tbz x8,#0x3f -> tbz w8,#0x1f)" % (OLD, NEW))
    elif cur == NEW:
        print("  UsbConfigDxe.patched.efi: already patched (0x%08X)" % NEW)
    else:
        die("UsbConfigDxe.patched.efi: unexpected bytes at 0x3fa8: 0x%08X" % cur)


def main():
    print("=== patch_usb143: restore HALIOMMU + harden UsbConfigDxe ===")
    if os.environ.get("NO_HAL") == "1":
        print("  NO_HAL=1 : skipping HALIOMMU DXE.inc/APRIORI.inc changes (fallback keys143b)")
    else:
        patch_dxe()
        patch_apriori()
    patch_ucfg()
    if _fail:
        print("PATCH_USB143 FAILED")
        sys.exit(1)
    print("PATCH_USB143 OK")


if __name__ == "__main__":
    main()
