#!/bin/bash
set -u
echo "=== build_keys144.sh patch chain ==="
grep -n "patch_usb143\|patch_clock144\|NO_HAL" /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys144.sh
echo
echo "=== _tools files (verify/log for 143/144/145) ==="
ls -l /mnt/d/本地项目-01/_tools/ | grep -Ei "v14[345]|b14[345]|patch_usb143|run144|verify144"
echo
echo "=== patch_usb143.py NO_HAL logic ==="
grep -n "NO_HAL\|NO_HAL" /mnt/d/本地项目-01/_tools/patch_usb143.py
echo
echo "=== verify144.sh contents (what it checked) ==="
sed -n '1,60p' /mnt/d/本地项目-01/_tools/verify144.sh 2>/dev/null
