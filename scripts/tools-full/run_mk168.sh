#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
python3 mk168.py || exit 1
echo "=== structural checks ==="
grep -n 'menu entered' patch_usb168.py
grep -n 'setup bm=' patch_usb168.py | head -3
grep -n 'devaddr' patch_usb168.py | head -3
grep -n 'alive evts' patch_usb168.py | head -3
grep -n 'replug retry' patch_usb168.py | head -3
grep -n 'ep0 armed' patch_usb168.py | head -4
grep -n 'Usb168Mark (' patch_usb168.py | wc -l
echo "=== forbidden (expect 0) ==="
grep -c 'FillRect\|Usb168Clear\|Usb168Line\|CpuDeadLoop\|Usb168Action' patch_usb168.py || true
echo "=== tail ==="
sed -n '/NEW_TAIL = /,/^.\{0,3\}$/p' patch_usb168.py | head -45
