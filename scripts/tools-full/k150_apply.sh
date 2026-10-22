#!/bin/bash
python3 /mnt/d/本地项目-01/_tools/patch_usb150.py || exit 1
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== call site ==="
grep -n -A14 'MENU150' "$F" | head -34
echo "=== block head ==="
L=$(grep -n 'Usb150Rd (' "$F" | head -1 | cut -d: -f1)
echo "start=$L"
sed -n "$((L-2)),$((L+18))p" "$F"
echo "=== block tail ==="
grep -n 'Usb150LateDiag\|Usb150Dump (L\|Usb150Dump (L"' "$F"
echo "=== brace balance of new block ==="
awk 'NR>=790 && NR<=1010' "$F" | tr -cd '{}' | awk '{o=gsub(/{/,"{"); c=gsub(/}/,"}"); print "open="o" close="c}'
