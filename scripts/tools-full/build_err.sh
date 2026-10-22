set +e
grep -n "002\|Error\|error:" /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | tail -20
echo "=== tail of apriori ==="
tail -6 /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== dsc components count SimpleFb ==="
grep -c "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc