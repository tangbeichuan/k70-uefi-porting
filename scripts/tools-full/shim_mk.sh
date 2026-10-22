set +e
cat /root/k70/uefi/BootShim/Makefile
echo "=== BootShim.S head ==="
sed -n '1,20p' /root/k70/uefi/BootShim/BootShim.S