set +e
cd /root/k70/uefi
echo "=== 所有 APRIORI.inc ==="
find . -name 'APRIORI.inc' | head
echo "=== vermeerPkg/Include/APRIORI.inc 里 halio 行（现在）==="
grep -n -i 'halio\|pmicdxe' Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc | head
echo "=== dsc/fdf 里 include APRIORI 的地方 ==="
grep -rn 'APRIORI.inc' Platforms/Xiaomi/vermeerPkg/*.dsc Platforms/Xiaomi/vermeerPkg/*.fdf Platforms/Xiaomi/vermeerPkg/Include/*.inc 2>/dev/null | head