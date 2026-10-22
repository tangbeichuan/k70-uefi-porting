set +e
grep -n "DROP\|drop" /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys73.sh | head -20
echo "=== build_keys73.sh DROP 段 ==="
sed -n '1,60p' /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys73.sh 2>/dev/null | grep -n "usb\|DROP\|token" | head -30