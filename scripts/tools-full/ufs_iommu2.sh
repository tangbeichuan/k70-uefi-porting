set +e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi
echo "=== 引用字符串 0x1bcec 的指令 ==="
grep -n "add	x[0-9]*, x[0-9]*, #0xcec" /tmp/ufs.asm | head
echo "=== 该区域上下文 ==="
L=$(grep -n "add	x[0-9]*, x[0-9]*, #0xcec" /tmp/ufs.asm | head -1 | cut -d: -f1)
echo "line=$L"
sed -n "$((L-45)),$((L+10))p" /tmp/ufs.asm