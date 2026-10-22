#!/usr/bin/env bash
# RamManagerDxe reads the RAM partition table published by the *vendor* stack
# (SMEM/DAL/RPMh). With VERMEER_VENDOR_HW = 0 nothing publishes it, so the driver
# can only assert or stall. sheng gates it the same way.
set -e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
src = open(p, encoding="utf-8").read()
old = "  INF SiliciumPkg/Drivers/RamManagerDxe/RamManagerDxe.inf\n"
new = ("!if $(VERMEER_VENDOR_HW) == 1\n"
       "  # Needs the RAM partition table from the vendor stack (SMEM/DAL/RPMh).\n"
       "  INF SiliciumPkg/Drivers/RamManagerDxe/RamManagerDxe.inf\n"
       "!endif\n")
if "VERMEER_VENDOR_HW) == 1\n  # Needs the RAM partition" in src:
    print("already patched")
elif old in src:
    open(p, "w", encoding="utf-8", newline="\n").write(src.replace(old, new, 1))
    print("patched: RamManagerDxe now behind VERMEER_VENDOR_HW")
else:
    print("PATTERN NOT FOUND")
PY
grep -n -A3 'VERMEER_VENDOR_HW' "$F" | head -12
