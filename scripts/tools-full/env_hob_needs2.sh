#!/bin/bash
set -e
cp /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi /tmp/EnvDxe.efi
echo "=== QcomPkg.dec HOB GUIDs ==="
sed -n '1,25p' /root/k70/uefi/Silicon/Qualcomm/QcomPkg/QcomPkg.dec
echo
echo "=== EnvDxe.efi GUID usage (values read from the .dec) ==="
python3 - <<'PY'
import re, uuid
dec = open('/root/k70/uefi/Silicon/Qualcomm/QcomPkg/QcomPkg.dec', encoding='utf-8', errors='ignore').read()
pairs = re.findall(r'(g\w+HobGuid|gEfiDtb\w*|gEfi\w+Guid)\s*=\s*\{([^}]*)\}', dec)
name2g = {}
for name, body in pairs:
    parts = [p.strip() for p in body.split(',') if p.strip()]
    if len(parts) == 11:
        g = "-".join([parts[0], parts[1], parts[2], parts[3]+parts[4], "".join(parts[5:])])
        name2g[name] = g.upper()
blob = open('/tmp/EnvDxe.efi', 'rb').read()
for name, g in sorted(name2g.items()):
    try:
        le = uuid.UUID(g).bytes_le
    except ValueError:
        print(f"  {name:26s} {g}  (unparseable)"); continue
    hits, i = [], blob.find(le)
    while i >= 0 and len(hits) < 3:
        hits.append(hex(i)); i = blob.find(le, i+1)
    print(f"  {name:26s} {g}  -> {hits or 'NOT FOUND'}")
PY