set +e
P=/mnt/d/本地项目-01/_k70port_extract/wsl/pack_keys.sh
echo "=== pack_keys.sh (first 40 lines) ==="
head -40 "$P"
echo "=== args usage ==="
grep -n "FD=\|\$1\|\$2\|SILICIUM_UEFI" "$P" | head -20