set +e
cd /root/k70/uefi
cp /tmp/APRIORI.inc.bak69 Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "restored APRIORI.inc:"; grep -c -i 'halio' Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== build_uefi.py 里有没有 git/checkout/clean ==="
grep -nE 'git|checkout|clean|restore' build_uefi.py | head -20
echo "=== 是否 git 仓库 ==="
ls -d .git 2>/dev/null && git -C . status --porcelain | head -5