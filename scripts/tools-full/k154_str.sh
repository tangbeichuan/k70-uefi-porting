#!/bin/bash
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
MED=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG/VermeerMenuDxe.efi
echo "=== source: ICFG / DCFG occurrences ==="
grep -n 'ICFG\|DCFG\|IcFg\|Dcfg' "$M" | head
echo "=== efi utf16: USB150 lines ==="
strings -el "$MED" | grep -n 'USB150\|USB152\|MENU152' | head -20
echo "=== efi: locate format string bytes ==="
python3 - "$MED" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
for pat in [b'cfg: PHYCFG', b'ICFG', b'DCFG', b'dev: DCTL', b'vbus readonly', b'after-run']:
    print(pat, 'utf16 at', [hex(i) for i in range(0,len(d)) if d[i:i+len(pat)*2]==pat.decode().encode('utf-16-le')][:3])
PY
