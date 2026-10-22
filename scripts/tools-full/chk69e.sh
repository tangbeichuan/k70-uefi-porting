set +e
cd /root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== dsc 里的 HALIOMMU ==="
grep -n -i 'halio' vermeer.dsc | head
echo "=== fdf 里 ==="
grep -n -i 'halio' vermeer.fdf | head
echo "=== APRIORI.inc 里 ==="
grep -n -i 'halio' Include/APRIORI.inc | head
echo "=== build 脚本怎么改 dsc 的 ==="
grep -n 'Binaries/vermeer\|DROP' /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys69.sh | head -20