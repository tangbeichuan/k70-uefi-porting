#!/bin/bash
set -u
TO=/mnt/d/本地项目-01/_tools
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd
E=/tmp/ucfg145.efi
[ -s "$E" ] || python3 $TO/cf146e.py "$FD" "$E" >/dev/null
[ -s /tmp/u145.asm ] || llvm-objdump -d "$E" > /tmp/u145.asm
echo "=== refs to #0xbbc / #0xbc7 / #0xbcf (strings: usb_repeater_init / WRITING / tuning) ==="
grep -n -E "add\s+x[0-9]+, x[0-9]+, #0x[b]c[0-9a-f]{1,2}\s*$" /tmp/u145.asm | head -20
grep -n -E "#0xbbc|#0xbc7|#0xbcf|#0xbc" /tmp/u145.asm | head -20
echo
echo "=== dump strings near RVA 0x12b80-0x12c80 of PE ==="
python3 - "$E" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
start=None
for o in range(0x12b60,0x12c80):
    c=d[o]
    if 32<=c<127:
        if start is None: start=o
    else:
        if start is not None and o-start>=3:
            print("  0x%05x %r"%(start,d[start:o]))
        start=None
PY
