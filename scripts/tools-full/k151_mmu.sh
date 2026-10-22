#!/bin/bash
# find which FV module contains "MMU: enabled" (ascii or utf16)
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
echo "=== raw counts in FVMAIN ==="
python3 - "$FV" <<'PY'
import sys
b=open(sys.argv[1],'rb').read()
for p in ('MMU: enabled','MMU:','Loading DxeCore','DxeCore','MMU enabled'):
    print('%-16s ascii=%d utf16=%d' % (p, b.count(p.encode('ascii')), b.count(p.encode('utf-16-le'))))
PY
echo "=== scan modules under FVMAIN for the string (via xref to build AARCH64 efi files) ==="
cd /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64
for f in $(find . -name '*.efi' | head -400); do
  if grep -aq 'MMU: enabled' "$f"; then echo "ASCII $f"; fi
  if python3 -c "
import sys
b=open('$f','rb').read()
sys.exit(0 if 'MMU: enabled'.encode('utf-16-le') in b else 1)"; then echo "UTF16 $f"; fi
done
