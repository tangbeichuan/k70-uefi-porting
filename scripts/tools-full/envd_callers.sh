#!/bin/bash
# Who calls EnvDxe's DtbExtn init (0x2ba8)?  Find bl targets and the guard around them.
cd /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe || exit 1
echo "=== all bl 0x2ba8 ==="
aarch64-linux-gnu-objdump -d EnvDxe.efi > /tmp/envdxe.dis 2>/dev/null
grep -n "bl[[:space:]]*0x2ba8" /tmp/envdxe.dis
echo
echo "=== entry point (PE AddressOfEntryPoint) ==="
python3 - <<'PY'
import struct
d=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi','rb').read()
pe=struct.unpack_from('<I', d, 0x3c)[0]
opt=pe+24
ep=struct.unpack_from('<I', d, opt+16)[0]
print("entry RVA = 0x%x" % ep)
PY
echo
echo "=== context around each caller ==="
for off in $(grep -n "bl[[:space:]]*0x2ba8" /tmp/envdxe.dis | cut -d: -f1); do
  start=$((off-14)); end=$((off+6))
  sed -n "${start},${end}p" /tmp/envdxe.dis
  echo "-----"
done
