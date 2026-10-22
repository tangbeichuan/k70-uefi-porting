#!/bin/bash
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
echo "=== UFSDxe.efi strings mentioning fdt/dtb/device tree ==="
strings -n 6 $B/UFSDxe/UFSDxe.efi 2>/dev/null | grep -iE 'fdt|dtb|device.?tree|dt_|platformhas' | head -40
echo
echo "=== which Mu libs do vendor DXEs link for DT? (check if any vendor efi references the config-table GUID b1b621d5) ==="
python3 - <<'PY'
import glob, uuid, os
# gFdtTableGuid = b1b621d5-f19c-41a5-830b-d9152c69aae0  (bytes little-endian per field)
g = uuid.UUID('b1b621d5-f19c-41a5-830b-d9152c69aae0').bytes_le
g2 = uuid.UUID('b1b621d5-f19c-41a5-830b-d9152c69aae0').bytes
hits = []
for p in glob.glob('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/*/*.efi') + glob.glob('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/*/*.EFI'):
    d = open(p,'rb').read()
    if g in d or g2 in d:
        hits.append(os.path.basename(p))
print('files containing gFdtTableGuid:', hits[:20], 'total', len(hits))
PY
