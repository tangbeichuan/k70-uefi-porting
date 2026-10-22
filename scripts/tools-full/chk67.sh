set +e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys14.sh
grep -n "DROP\|ufsdxe\|envdxe\|pmicdxe" "$B" | head -30
echo "=== runner ==="
ls /mnt/d/本地项目-01/_k70port_extract/wsl/ | grep -E "keys6[0-9]|keys5[5-9]" | head -20