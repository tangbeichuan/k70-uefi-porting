#!/bin/bash
set -u
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
echo "== sections =="
llvm-readobj --sections "$F" | grep -E "Name:|VirtualAddress|PointerToRawData|VirtualSize|RawDataSize"
echo "== raw GUID reads =="
python3 - "$F" <<'EOF'
import sys, uuid
f = sys.argv[1]
d = open(f, "rb").read()
for o in (0x16070, 0x16078, 0x16098, 0x15098, 0x14098):
    print(hex(o), uuid.UUID(bytes_le=d[o:o+16]))
EOF
