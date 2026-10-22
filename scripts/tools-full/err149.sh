set +e
grep -n -A5 'error' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | grep -i -E 'error|warning' | tail -20
echo "=== last lines mentioning VermeerMenuDxe ==="
grep -i 'VermeerMenuDxe' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | tail -10
echo "=== clang errors ==="
grep -i 'error:' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | tail -10