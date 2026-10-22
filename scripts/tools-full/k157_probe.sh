#!/usr/bin/env bash
set -e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys156.sh
echo "--- extn/copy/menu patch lines ---"
grep -nE 'patch_extn136|patch_copy123|patch_menu101|patch_usb157' "$B"
echo "--- tool files ---"
ls -l /mnt/d/本地项目-01/_tools/patch_usb157.py /mnt/d/本地项目-01/_tools/run157.sh 2>/dev/null || true
echo "--- extn136 source path ---"
grep -nE 'port-drivers|SRC|DST|copy' /mnt/d/本地项目-01/_tools/patch_extn136.py | head -12
