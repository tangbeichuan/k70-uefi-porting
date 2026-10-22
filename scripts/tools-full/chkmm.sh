set +e
sed -n '55,75p' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "=== 有没有 UFS ==="
grep -n -i 'ufs' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c | head