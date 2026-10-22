set +e
L=/root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt
wc -l "$L"
grep -n "F002\|error:\|Error:" "$L" | tail -15
echo "=== context around last error ==="
grep -n "F002" "$L" | tail -1 | cut -d: -f1 | while read n; do sed -n "$((n-25)),$((n+3))p" "$L"; done