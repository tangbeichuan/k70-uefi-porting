#!/bin/bash
f=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "file: $f ($(stat -c%s "$f") B)"
grep -n 'Usb168Mark (' "$f" | head -3
echo "--- mark body ---"
sed -n '/^Usb168Mark (/,/^}/p' "$f" | cat -A | head -30
echo "--- raw CR count in mark region ---"
python3 - "$f" <<'PY'
import sys
d = open(sys.argv[1],'rb').read()
i = d.find(b'Usb168Mark (')
j = d.find(b'Usb168Print', i)
if i >= 0 and j > i:
    seg = d[i:j]
    print("region bytes:", len(seg), "CR:", seg.count(b'\r'), "LF:", seg.count(b'\n'), "backslash-r:", seg.count(b'\\r'))
else:
    print("Usb168Mark not found in generated source (i=%d j=%d)" % (i, j))
PY
