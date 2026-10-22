#!/usr/bin/env bash
# Build a QEMU-only firmware variant that combines the banner/heartbeat driver with the
# PL011 serial console, so the same source that ships to the phone can be *read* on a
# development machine (see the guide, sections 8.16 and 8.17).
#
# Never goes near the phone: the GIC and UART base addresses are QEMU's, and the two extra
# MMIO windows in MemoryMapLib.c are compiled in only with QEMU_BRINGUP = 1.
set -uo pipefail
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
DSC=$PKG/vermeer.dsc
FDF=$PKG/vermeer.fdf
MMAP=$PKG/Library/MemoryMapLib/MemoryMapLib.c
SRC=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerBannerDxe
GATES=/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py
OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
FKEEP=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
mkdir -p "$OUT" "$PKG/Drivers/VermeerBannerDxe"

cp -f "$SRC/VermeerBannerDxe.c" "$SRC/VermeerBannerDxe.inf" "$PKG/Drivers/VermeerBannerDxe/"

# 1. scaffolding + both gates on
python3 "$GATES" banner "$DSC" "$FDF"
python3 "$GATES" qemu "$DSC" enable
python3 "$GATES" set "$DSC" VERMEER_BANNER 1
echo "gates: $(grep -E '^\s+(VERMEER_(PAINT|BANNER|VENDOR_HW)|QEMU_BRINGUP)' "$DSC" | tr -s ' ' | tr '\n' ' ')"

# 2. two QEMU MMIO windows, so the serial console survives the MMU being enabled.
#    Without these the log stops at "MMU: HOBs built, enabling" (writing 0x09000000 faults).
python3 - "$MMAP" <<'PY'
import sys
p = sys.argv[1]
c = open(p).read()
if "QEMU GIC" not in c:
    extra = """#if defined (QEMU_BRINGUP)
  {"QEMU GIC",            0x08000000, 0x00100000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},
  {"QEMU PL011 UART",     0x09000000, 0x00100000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},
#endif
"""
    anchor = "\n};\n\nVOID\nGetMemoryMap"
    assert anchor in c, "memory map array anchor not found"
    open(p, "w").write(c.replace(anchor, "\n" + extra + "};\n\nVOID\nGetMemoryMap", 1))
    print("MemoryMapLib.c: two QEMU windows added")
else:
    print("MemoryMapLib.c: QEMU windows already present")
PY
cp -f "$MMAP" /root/k70/MemoryMapLib.c.qemu

cd "$UEFI"
source /root/k70/venv/bin/activate
echo "=== building banner+serial (QEMU) variant ==="
if python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/banner-qemu-build.log 2>&1; then
  grep -E 'Success|Images Verified' /root/k70/banner-qemu-build.log | tail -3
  cp -f "$FKEEP" "$OUT/SILICIUM_UEFI-banner-qemu.fd"
  sha256sum "$OUT/SILICIUM_UEFI-banner-qemu.fd"
else
  echo "!! build FAILED - see /root/k70/banner-qemu-build.log"
  grep -Ei 'error|not found|failed' /root/k70/banner-qemu-build.log | tail -12
fi

# 3. restore: gates off, QEMU MMIO windows removed, plain FD rebuilt
python3 "$GATES" set "$DSC" VERMEER_BANNER 0
python3 "$GATES" set "$DSC" QEMU_BRINGUP 0
python3 - "$MMAP" <<'PY'
import re, sys
p = sys.argv[1]
c = open(p).read()
c2 = re.sub(r'#if defined \(QEMU_BRINGUP\)\n(  \{"QEMU GIC".*?\n  \{"QEMU PL011 UART".*?\n)#endif\n', '', c, flags=re.S)
if c2 != c:
    open(p, "w").write(c2)
    print("MemoryMapLib.c: QEMU windows removed")
PY
echo "=== restored; rebuilding default FD ==="
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -2
sha256sum "$FKEEP"
