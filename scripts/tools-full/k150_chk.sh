#!/bin/bash
M=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG/VermeerMenuDxe.efi
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
SRC=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== source has USB150 ==="
grep -c 'USB150' "$SRC"
echo "=== pkg copy has USB150 ==="
grep -c 'USB150' "$PKG" 2>/dev/null
grep -n 'MENU150\|Usb150LateDiag' "$PKG" 2>/dev/null | head -5
echo "=== menu efi size ==="
ls -l "$M"
echo "=== menu efi utf16 USB150 ==="
python3 - "$M" <<'PY'
import sys
b=open(sys.argv[1],'rb').read()
for pat in ('USB150','MENU150','GSNPSID=','gsts_b0','GCC_GDSCR','USB149'):
    u=pat.encode('utf-16-le'); a=pat.encode('ascii')
    print(pat, 'utf16:', b.count(u), 'ascii:', b.count(a))
PY
echo "=== FVMAIN.Fv utf16 USB150 ==="
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
python3 - "$FV" <<'PY'
import sys
b=open(sys.argv[1],'rb').read()
print('size', len(b))
for pat in ('USB150','MENU150','GCC_GDSCR','gsts_b0'):
    print(pat, 'utf16:', b.count(pat.encode('utf-16-le')), 'ascii:', b.count(pat.encode('ascii')))
PY
