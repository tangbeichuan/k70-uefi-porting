#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/ucfg.asm
echo "=== sections ==="
llvm-readobj --sections "$F" | grep -E "Name:|VirtualAddress|PointerToRawData|RawDataSize|VirtualSize" | head -30
echo "=== function region 0x3f80 - 0x4070 ==="
awk '/^0000000000003[fF]/{p=1} p' /tmp/ucfg.asm | sed -n '1,200p' | grep -n "" | sed -n '1,200p'
echo "=== crash code 0x3f00-0x4020 ==="
python3 - <<'PY'
import re
ins=[]
for L in open('/tmp/ucfg.asm'):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', L)
    if m: ins.append((int(m.group(1),16), m.group(2), m.group(3).strip()))
for a,m,o in ins:
    if 0x3f00 <= a <= 0x4020:
        print(hex(a), m, o)
PY
