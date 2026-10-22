set +e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys111.sh
sed -n '40,60p' "$B"
echo "=== patch invocations ==="
grep -n 'python3\|patch_' "$B" | head -20
echo "=== tail ==="
sed -n '70,100p' "$B"