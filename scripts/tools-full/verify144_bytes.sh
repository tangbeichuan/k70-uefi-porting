#!/bin/bash
# keys144 byte-level re-checks (correct little-endian GUID byte order)
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
python3 - "$FV" <<'PY'
import sys,struct,uuid
fv=open(sys.argv[1],'rb').read()
def g(s):
    return uuid.UUID(s).bytes_le
tests=[
 ("ClockDxe FFS GUID 4DB5DEA6...", "4DB5DEA6-5302-4D1A-8A82-677A683B0D29"),
 ("UsbConfigDxe FFS GUID CD823A4D...", "CD823A4D-7DEC-4531-AE5D-4134FA4127B8"),
 ("AcpiTableDxe FFS GUID 9622E42C...", "9622E42C-8E38-4A08-9E8F-54F784652F6B"),
 ("gEfiClockProtocolGuid 241AFAE6...", "241AFAE6-885F-4F6C-A7EA-C28EAB79C3E5"),
 ("HALIOMMU 54B6D3B4...", "54B6D3B4-5D33-4F91-8600-6C41D5DEB19A"),
]
for name,guid in tests:
    print("  %-42s %d" % (name, fv.count(g(guid))))
# where does the clock protocol GUID live
i=0; offs=[]
while True:
    i=fv.find(g("241AFAE6-885F-4F6C-A7EA-C28EAB79C3E5"),i)
    if i<0: break
    offs.append(hex(i)); i+=1
print("  gEfiClockProtocolGuid offsets:", ", ".join(offs) if offs else "none")
# ClockDxe FFS header
i=fv.find(g("4DB5DEA6-5302-4D1A-8A82-677A683B0D29"))
if i>=0:
    import struct
    print("  ClockDxe FFS header @0x%x  size=%d" % (i, struct.unpack("<I", fv[i+20:i+24])[0]))
PY
