set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "=== UfsMap mentions in build_keys146.sh ==="
grep -n 'UfsMap\|ufsmap' build_keys146.sh | head -20
echo "=== patch scripts mentioning UfsMap ==="
grep -l 'UfsMap' /mnt/d/本地项目-01/_tools/*.py 2>/dev/null