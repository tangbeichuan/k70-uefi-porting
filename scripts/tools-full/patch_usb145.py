#!/usr/bin/env python3
"""keys145: keep ClockDxe (keys144) and additionally

  A) restore the vendor HAL IOMMU producer (DXE.inc + APRIORI.inc) exactly like
     patch_usb143 does when NO_HAL is unset -- this makes the globals
       0x13768 gIommu  /  0x13770 gIommuCtx
     non-NULL so every optional-IOMMU path in UsbConfigDxe is valid, and
  B) add a defensive NULL guard for the crash already observed on keys144:
     UsbConfigDxe teardown path
         53c4 adrp x8,0x13000
         53c8 ldr  x8,[x8,#0x770]     ; x8 = gIommuCtx  (can be NULL)
         53cc ldr  x8,[x8,#0x8]       ; <-- fault: FAR = 0x8 when gIommuCtx == NULL
         ...
     is rewritten so that a NULL context cannot be dereferenced:
         53cc cbz  x8, 0x53f0         ; new: skip teardown when ctx == NULL
         53d0 ldr  x8, [x8, #0x8]     ; method pointer (moved down)
         53d4 adrp x9, 0x13000        ; was 'str x9,[sp]'
         53d8 ldr  x0, [x9, #0x778]
         53dc blr  x8
         53e0 adrp x9, 0x13000        ; was 'ldr x9,[sp]'
         53e4 mov  x8, xzr
         53e8 str  x8, [x9, #0x778]
         53ec b    0x53f0
     All four u32 writes are verified against the expected original bytes, so the
     patch is idempotent and fails loudly if the image does not match.

File offset == RVA for this image (.text VA=0x1000 raw=0x1000).
run145.sh backs the .efi up to /tmp/...bak145 and restores it after the build.
"""
import os
import re
import sys

PKG = "/root/k70/uefi/Platforms/Xiaomi/vermeerPkg"
DXE = PKG + "/Include/DXE.inc"
APRIORI = PKG + "/Include/APRIORI.inc"
INF_HAL = "INF Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.inf"
INF_PROV = "INF vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf"
UCFG = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"

# (offset, original_u32, patched_u32, comment)
PATCHES = [
    (0x53CC, 0xF9400508, 0xB4000128, "ldr x8,[x8,#8] -> cbz x8,0x53f0"),
    (0x53D0, 0xD0000069, 0xF9400508, "adrp x9,0x13000 -> ldr x8,[x8,#8]"),
    (0x53D4, 0xF90003E9, 0xD0000069, "str x9,[sp] -> adrp x9,0x13000"),
    (0x53E0, 0xF94003E9, 0xD0000069, "ldr x9,[sp] -> adrp x9,0x13000"),
]

_fail = []


def die(msg):
    _fail.append(msg)
    print("PATCH_USB145 FATAL: " + msg)


def read_lines(p):
    with open(p, "r", encoding="utf-8", errors="surrogateescape") as f:
        return f.read().split("\n")


def write_lines(p, lines):
    with open(p, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write("\n".join(lines))


def uncomment_hard(lines, needle, where):
    for i, ln in enumerate(lines):
        s = ln.strip()
        if not (s.startswith("#") and needle in s):
            continue
        m = re.match(r"^(\s*)#\s*\[keys?\d*-hard\]\s*(INF\s+.*)$", ln)
        if not m:
            die("%s: unexpected commented form: %r" % (where, ln))
            return
        lines[i] = m.group(1) + "  " + m.group(2)
        return
    if not any(ln.strip().startswith("INF ") and needle in ln for ln in lines):
        die("%s: HALIOMMU line neither active nor keys70-hard" % where)


def restore_hal():
    lines = read_lines(DXE)
    uncomment_hard(lines, "HALIOMMUDxe", "DXE.inc")
    write_lines(DXE, lines)
    print("  DXE.inc: HALIOMMUDxe active")

    lines = read_lines(APRIORI)
    if not any("HALIOMMUDxe" in ln for ln in lines):
        die("APRIORI.inc: HALIOMMUDxe line not found")
        return
    uncomment_hard(lines, "HALIOMMUDxe", "APRIORI.inc")
    hi = next(i for i, ln in enumerate(lines) if "HALIOMMUDxe" in ln)
    if not any("VermeerDtbExtnDxe" in ln for ln in lines):
        indent = re.match(r"^(\s*)", lines[hi]).group(1)
        lines.insert(hi, indent + INF_PROV)
        print("  APRIORI.inc: inserted VermeerDtbExtnDxe line %d" % (hi + 1))
    write_lines(APRIORI, lines)
    pi = next(i for i, ln in enumerate(lines) if "VermeerDtbExtnDxe" in ln)
    hi = next(i for i, ln in enumerate(lines) if "HALIOMMUDxe" in ln)
    if pi > hi:
        die("APRIORI.inc: provider (%d) after HALIOMMU (%d)" % (pi + 1, hi + 1))
    else:
        print("  APRIORI.inc: provider %d < HALIOMMU %d OK" % (pi + 1, hi + 1))


def patch_ucfg():
    if not os.path.exists(UCFG):
        die("UsbConfigDxe.patched.efi missing")
        return
    data = bytearray(open(UCFG, "rb").read())
    todo = 0
    for off, old, new, note in PATCHES:
        cur = int.from_bytes(data[off:off + 4], "little")
        if cur == old:
            data[off:off + 4] = new.to_bytes(4, "little")
            todo += 1
            print("  UsbConfigDxe 0x%04x: 0x%08X -> 0x%08X  (%s)" % (off, old, new, note))
        elif cur == new:
            print("  UsbConfigDxe 0x%04x: already patched (0x%08X)" % (off, new))
        else:
            die("UsbConfigDxe 0x%04x unexpected: 0x%08X (want 0x%08X)" % (off, cur, old))
    if todo:
        open(UCFG, "wb").write(bytes(data))


def main():
    print("=== patch_usb145: restore HALIOMMU + NULL-guard UsbConfigDxe teardown ===")
    if os.environ.get("NO_HAL") == "1":
        print("  NO_HAL=1 : HALIOMMU stays out")
    else:
        restore_hal()
    patch_ucfg()
    if _fail:
        print("PATCH_USB145 FAILED")
        sys.exit(1)
    print("PATCH_USB145 OK")


if __name__ == "__main__":
    main()
