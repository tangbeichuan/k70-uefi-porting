#!/usr/bin/env bash
# Follow sheng exactly for phase 0: its fdf comments DtPlatformDxe + the embedded
# FDT blob out. Phase 0 has no vendor driver that consumes the DT, so this
# removes one moving part from the first-boot attempt.
set -e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
src = open(p, encoding="utf-8").read()
if "ShengGopLogDxe-style" in src or "#INF EmbeddedPkg/Drivers/DtPlatformDxe" in src:
    print("already patched")
else:
    old = """  INF EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf
  FILE FREEFORM = 25462CDA-221F-47DF-AC1D-259CFAA4E326 {
    SECTION RAW = vermeerPkg/FdtBlob/sm8550-xiaomi-vermeer.dtb
    SECTION UI = "Device Tree"
  }
"""
    new = """  #
  # Phase 0 (VERMEER_VENDOR_HW = 0) has no driver that consumes the device
  # tree, and sheng's verified image leaves these disabled as well. BootShim
  # still appends Resources/DTBs/vermeer.dtb to the boot image, which is what
  # the previous stage reads for /reserved-memory/splash_region. Re-enable
  # together with the vendor hardware drivers.
  #
  #INF EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf
  #FILE FREEFORM = 25462CDA-221F-47DF-AC1D-259CFAA4E326 {
  #  SECTION RAW = vermeerPkg/FdtBlob/sm8550-xiaomi-vermeer.dtb
  #  SECTION UI = "Device Tree"
  #}
"""
    if old not in src:
        print("PATTERN NOT FOUND")
        sys.exit(1)
    open(p, "w", encoding="utf-8", newline="\n").write(src.replace(old, new, 1))
    print("patched: DtPlatformDxe + FdtBlob disabled (matches sheng)")
PY
grep -n 'DtPlatformDxe' "$F"
