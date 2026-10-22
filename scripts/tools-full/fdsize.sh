set +e
echo "=== FD_BLOCKS source ==="
grep -rn 'FD_BLOCKS' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/ 2>/dev/null | head
grep -rn 'FD_BLOCKS' /root/k70/uefi/Build/*.sh /root/k70/*.sh 2>/dev/null | head
echo "=== build_uefi FD_BLOCKS ==="
grep -rn 'FD_BLOCKS\|FD_SIZE\|0x300000' /root/k70/uefi/build_uefi.py 2>/dev/null | head
echo "=== pack_keys.sh ==="
sed -n '1,60p' /mnt/d/本地项目-01/_k70port_extract/wsl/pack_keys.sh