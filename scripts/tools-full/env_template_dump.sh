#!/bin/bash
set -e
cd /tmp
cp /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi EnvDxe.efi
echo "=== 264-byte template at file offset 0xe470 (VMA 0xe470) ==="
python3 - <<'PY'
import struct
b = open('/tmp/EnvDxe.efi','rb').read()
tpl = b[0xe470:0xe470+0x108]
for i in range(0, 0x108, 8):
    v = struct.unpack_from('<Q', tpl, i)[0]
    tag = ''
    if 0x1000 <= v < 0xe000: tag = '  <- likely EnvDxe code RVA'
    elif v == 0: tag = '  (null)'
    print(f"  +0x{i:03x}  {v:#018x}{tag}")
PY
echo
echo "=== does code near the install write into 0xe470.. beyond CopyMem? (0x2ba8..0x2c20 already seen) ==="
echo "--- search for adrp/add pairs referencing 0xe470 ---"
aarch64-linux-gnu-objdump -d EnvDxe.efi | grep -n "0xe470\|#0x470" | head -20
