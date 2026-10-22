#!/bin/bash
# verify146c.sh -- debug: which module GUIDs are visible in FVMAIN.Fv right now,
# and where is UsbConfigDxe's FFS (search by unique byte runs / FFS file path).
set -u
FVF=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
ls -l $FVF
python3 - "$FVF" <<'PY'
import sys, uuid
d = open(sys.argv[1], 'rb').read()
print("FVMAIN.Fv size =", len(d), hex(len(d)))
guids = {
 'UsbConfigDxe':'CD823A4D-7DEC-4531-AE5D-4134FA4127B8',
 'HALIOMMU':'9A00771F-36D4-4DD5-8916-C48ED9B16B86',
 'ClockDxe':'4DB5DEA6-5302-4D1A-8A82-677A683B0D29',
 'UsbInitDxe':'0A134F0E-075E-40B3-9C63-3B3906804663',
 'AcpiTableDxe':'9622E42C-8E38-4a08-9E8F-54F784652F6B',
 'DtbExtn':'5B21E7C4-3D18-4F6A-9A20-8C7E51FD42B9',
}
for name, g in guids.items():
    b = uuid.UUID(g).bytes_le
    hits = []
    i = 0
    while True:
        i = d.find(b, i)
        if i < 0: break
        hits.append(i); i += 1
    print("%-14s hits=%s" % (name, [hex(x) for x in hits]))
# look for PE images (MZ) and their first-section heuristics
pos = [i for i in range(0, len(d), 1) if d.startswith(b'MZ', i)] if len(d) < 2_000_000 else None
print("MZ count:", d.count(b'MZ'))
# search for distinctive UsbConfigDxe strings
for s in (b'UsbConfigCoresInit', b'UsbConfigLibOpenProtocols', b'Failed to open HAL IOMMU protocol'):
    idx = []
    i = 0
    while True:
        i = d.find(s, i)
        if i < 0: break
        idx.append(i); i += 1
    print("%-36s -> %s" % (s.decode(), [hex(x) for x in idx]))
PY
