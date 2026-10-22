set +e
grep -rn 'fd_config' /root/k70/uefi/build_uefi.py | head -8
echo "=== search config files mentioning 3145728 or 0x300000 ==="
grep -rln '3145728\|0x300000\|"blocks"' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/*.json /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/**/*.json 2>/dev/null | head
find /root/k70/uefi/Platforms/Xiaomi/vermeerPkg -name '*.json' | head