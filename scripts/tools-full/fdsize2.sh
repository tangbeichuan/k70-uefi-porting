set +e
echo "=== build_uefi.py around fd_blocks ==="
sed -n '185,240p' /root/k70/uefi/build_uefi.py
echo "=== BootShim SIZE define ==="
grep -rn 'FD_SIZE\|FD_BASE' /root/k70/uefi/BootShim/*.S 2>/dev/null | head
ls /root/k70/uefi/BootShim/ 2>/dev/null | head