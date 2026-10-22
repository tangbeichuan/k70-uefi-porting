set +e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
sed -n '150,190p' "$F"
echo "=== FD_BLOCKS define ==="
grep -rn 'FD_BLOCKS' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/*.dsc /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/*.fdf 2>/dev/null | head -5