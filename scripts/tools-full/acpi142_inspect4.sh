#!/bin/bash
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "=== run_keys141.sh (head 40) ==="
head -40 run_keys141.sh
echo "=== TAG/FD_OUT/LOG vars in build_keys141.sh ==="
grep -n "TAG=\|FD_OUT=\|LOG=\|vermeerPkg" build_keys141.sh | head -20
