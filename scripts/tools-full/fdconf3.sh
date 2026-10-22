set +e
grep -rn 'def parse_device_config' -A12 /root/k70/uefi/build_uefi.py | head -20
echo "=== resources configs ==="
ls /root/k70/uefi/Resources/Configs/ 2>/dev/null | head -20
grep -rn 'uefi_fd' -A6 /root/k70/uefi/Resources/Configs/*.json 2>/dev/null | head -20