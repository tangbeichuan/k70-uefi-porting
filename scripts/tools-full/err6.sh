set +e
L=/root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt
grep -n "ERROR 2000\|same file GUID\|GenFv: ERROR\|error 7000\|F002" "$L" | tail -6
echo "=== apriori SimpleFb count (post-run) ==="
grep -c "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc 2>/dev/null
grep -c "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf 2>/dev/null
grep -c "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc 2>/dev/null