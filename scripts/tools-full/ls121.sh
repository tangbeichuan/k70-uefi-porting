set +e
ls -t /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys12*.sh 2>/dev/null | head -5
echo "=== grep DROP in latest run ==="
L=$(ls -t /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys12*.sh | head -1)
echo "file: $L"
grep -n "DROP\|usb\|Usb" "$L" | head -40