#!/usr/bin/env bash
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "=== files ==="
ls -la build_keys152.sh build_keys155.sh run_keys155.sh 2>/dev/null
echo
echo "=== diff build_keys152.sh build_keys155.sh ==="
diff build_keys152.sh build_keys155.sh | head -60
echo
echo "=== diff run_keys152.sh run_keys155.sh ==="
diff run_keys152.sh run_keys155.sh | head -40
echo
echo "=== grep gcc in build_keys155.sh ==="
grep -n 'gcc155\|GCC' build_keys155.sh | head
echo
echo "=== any Build/ rm or clean steps ==="
grep -nE 'rm -|clean|touch ' build_keys152.sh build_keys155.sh | head -20
