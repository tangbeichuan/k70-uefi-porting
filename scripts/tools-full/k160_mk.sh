#!/usr/bin/env bash
set -e
cd /mnt/d/本地项目-01/_tools
python3 - <<'PY'
import io
s = io.open('patch_usb159.py', encoding='utf-8').read()
s = s.replace('159', '160')
io.open('patch_usb160.py', 'w', encoding='utf-8', newline='\n').write(s)
print('wrote patch_usb160.py', len(s))
PY
grep -c 160 patch_usb160.py
grep -c 159 patch_usb160.py || true
