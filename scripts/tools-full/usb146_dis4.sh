#!/bin/bash
# usb146_dis4.sh -- self-contained: extract, find function start of IOMMU init,
# HALIOMMU install site, strings around error paths
set -u
TO=/mnt/d/本地项目-01/_tools
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd
python3 $TO/cf146e.py "$FD" /tmp/ucfg145.efi >/dev/null
E=/tmp/ucfg145.efi
H=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi

echo "===== function start: 0x3D80-0x3F70 ====="
llvm-objdump -d --start-address=0x3d80 --stop-address=0x3f70 "$E" | sed -n '/Disassembly/,$p'
echo
echo "===== all bl targets into 0x3e80..0x3f68 (find callers of this function) ====="
llvm-objdump -d "$E" > /tmp/u145.asm
grep -oE "bl\s+0x3[0-9a-f]{3}" /tmp/u145.asm | sort | uniq -c | head -30
echo
echo "===== strings 0x11070-0x11180 in UsbConfigDxe ====="
python3 - "$E" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
for o in range(0x11070,0x11180):
    if d[o]==0 or d[o]<32: continue
start=None
for o in range(0x11070,0x11180):
    c=d[o]
    if 32<=c<127:
        if start is None: start=o
    else:
        if start is not None and o-start>=4:
            print("  0x%05x %r"%(start,d[start:o]))
        start=None
PY
echo
echo "===== HALIOMMU: code referencing 0xd068 (GUID) ====="
llvm-objdump -d "$H" > /tmp/h145.asm
python3 - <<'PY'
import re
lines=open('/tmp/h145.asm',errors='ignore').read().splitlines()
# find adrp 0xd000 followed within 12 lines by add #0x68
for i,l in enumerate(lines):
    if re.search(r'adrp\s+x\d+, 0xd000', l):
        win=lines[i:i+14]
        if any(re.search(r'#0x68\s*$',w) for w in win):
            print("--- context @", l.strip())
            for w in lines[max(0,i-10):i+18]:
                print(w)
            print()
PY
