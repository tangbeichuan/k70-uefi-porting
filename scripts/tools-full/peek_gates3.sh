set +e
sed -n '100,150p' /mnt/d/本地项目-01/_k70port_extract/wsl/gates.py
echo "=== constants: KEYPROBE_COMPONENT etc ==="
grep -n "KEYPROBE_COMPONENT\|KEYPROBE_FDF\|VENDOR_INPUT_COMPONENT\|VENDOR_INPUT_FDF" /mnt/d/本地项目-01/_k70port_extract/wsl/gates.py