#!/bin/bash
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "=== files ==="; ls -1t *.sh | head -8
echo
echo "=== build_keys23.sh: head 20 ==="
head -20 build_keys23.sh
echo
echo "=== build_keys23.sh: APRIORI / Pcd anchor lines ==="
grep -n "Pcd.inf\|APRIORI\|TAG=\|DtDump\|DtPlatform" build_keys23.sh
echo
echo "=== run_keys23.sh ==="
cat run_keys23.sh 2>/dev/null || echo "(no run_keys23.sh)"
