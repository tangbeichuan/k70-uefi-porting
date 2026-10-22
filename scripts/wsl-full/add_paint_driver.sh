#!/usr/bin/env bash
# Add VermeerPaintDxe to the port, gated by VERMEER_PAINT (default 0), then
# build a paint-enabled firmware + boot image without touching the shipping set.
set -euo pipefail
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
SRC=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerPaintDxe

mkdir -p "$PKG/Drivers/VermeerPaintDxe"
cp "$SRC/VermeerPaintDxe.c" "$SRC/VermeerPaintDxe.inf" "$PKG/Drivers/VermeerPaintDxe/"

# --- DSC: default define + gated component -----------------------------------
if ! grep -q 'VERMEER_PAINT' "$PKG/vermeer.dsc"; then
  python3 - "$PKG/vermeer.dsc" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = re.search(r'(?m)^  VERMEER_VENDOR_HW[^\n]*\n', s)
assert m, 'VERMEER_VENDOR_HW define missing in DSC'
s = s[:m.end()] + '  VERMEER_PAINT                   = 0\n' + s[m.end():]
s = s.rstrip('\n') + '''

!if $(VERMEER_PAINT) == 1
  vermeerPkg/Drivers/VermeerPaintDxe/VermeerPaintDxe.inf
!endif
'''
open(p, 'w').write(s)
PY
fi

# --- FDF: gated INF ----------------------------------------------------------
if ! grep -q 'VermeerPaintDxe' "$PKG/vermeer.fdf"; then
  python3 - "$PKG/vermeer.fdf" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = 'INF SiliciumPkg/Sec/Sec.inf'
assert anchor in s, 'Sec.inf anchor missing in FDF'
s = s.replace(anchor, anchor + '''
!if $(VERMEER_PAINT) == 1
  INF vermeerPkg/Drivers/VermeerPaintDxe/VermeerPaintDxe.inf
!endif''', 1)
open(p, 'w').write(s)
PY
fi

echo "=== patched ==="
grep -n 'VERMEER_PAINT' "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
grep -n 'VermeerPaintDxe' "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
