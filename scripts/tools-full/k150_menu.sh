#!/bin/bash
M=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG/VermeerMenuDxe.efi
echo "=== size ==="; ls -l "$M"
echo "=== utf16 counts ==="
python3 - "$M" <<'PY'
import sys
b=open(sys.argv[1],'rb').read()
for p in ('BlockIO devices','BlockIO','[UI]','MENU150','USB150','USB150','console stays on','GSNPSID='):
    print('%-20s utf16=%d ascii=%d' % (p, b.count(p.encode('utf-16-le')), b.count(p.encode('ascii'))))
PY
echo "=== wide strings sample ==="
strings -el "$M" | grep -i 'blockio\|usb150\|menu' | head -10
echo "=== ascii strings sample ==="
strings "$M" | grep -i 'blockio\|usb150\|menu' | head -10
