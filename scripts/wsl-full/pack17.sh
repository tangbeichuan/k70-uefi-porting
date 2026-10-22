#!/bin/bash
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys17.fd keys17 2>&1 | tail -20
echo "=== artifacts ==="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys17*.img
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys17*.img
echo "=== DT inside FD? (search FFS GUID + FDT magic in decompressed FVMAIN) ==="
python3 - <<'PY'
import struct, lzma, io
p = '/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys17.fd'
d = open(p, 'rb').read()
print('FD size', len(d))
guid = bytes.fromhex('da4c4622') + bytes.fromhex('1f22') + bytes.fromhex('df47') + bytes.fromhex('ac1d259cfaa4e326')
print('FFS header GUID raw present:', guid in d)
print('FDT magic in FD:', d.count(bytes.fromhex('d00dfeed')))
print('ufs0 in FD:', b'vermeer-uefi-kailua' in d)
# try to decompress any LZMA section we can find
i = d.find(b'\x5d\x00\x00\x00')
print('first lzma-ish marker at', hex(i) if i>=0 else 'none')
found = 0
pos = 0
while True:
    pos = d.find(bytes.fromhex('d00dfeed'), pos)
    if pos < 0:
        break
    found += 1
    pos += 4
print('fdt count', found)
PY
