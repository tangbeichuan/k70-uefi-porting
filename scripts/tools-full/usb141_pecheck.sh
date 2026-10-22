#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
llvm-readobj --sections "$F" 2>/dev/null | grep -E 'Name:|VirtualAddress:|PointerToRawData:'
echo '--- bytes at file 0x10c68 ---'
xxd -s 0x10c68 -l 0x40 "$F"
python3 - <<'PY'
F='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi'
d=open(F,'rb').read()
for s in [b'Failed to Locate SDT', b'QUFN', b'\\_SB', b'AdvanceSSCmplPattern']:
    i=d.find(s); print(s, hex(i) if i>=0 else 'notfound')
PY
