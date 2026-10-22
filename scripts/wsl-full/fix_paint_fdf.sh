#!/usr/bin/env bash
# Move VermeerPaintDxe from FVMAIN_COMPACT (XIP, must be section-==file-aligned)
# into FvMain (compressed, normal DXE driver rules apply).
set -euo pipefail
FDF=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
python3 - "$FDF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()

bad = '''
!if $(VERMEER_PAINT) == 1
  INF vermeerPkg/Drivers/VermeerPaintDxe/VermeerPaintDxe.inf
!endif'''
assert bad in s, 'expected block not found'
s = s.replace(bad, '', 1)

anchor = '  !include Include/RAW.inc\n'
assert anchor in s
s = s.replace(anchor, anchor + '''
  # Early frame buffer telemetry (VERMEER_PAINT=1 only). Must live in the
  # compressed FV: files in FVMAIN_COMPACT are executed in place and GenFv
  # demands SectionAlignment == FileAlignment for those.
!if $(VERMEER_PAINT) == 1
  INF vermeerPkg/Drivers/VermeerPaintDxe/VermeerPaintDxe.inf
!endif
''', 1)
open(p, 'w').write(s)
print('patched')
PY
grep -n -A3 'VERMEER_PAINT' "$FDF"
