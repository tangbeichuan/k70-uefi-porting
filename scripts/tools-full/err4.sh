set +e
L=/root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt
grep -n "No rule to make target\|error 7000\|Failed to execute" "$L" | tail -5
echo "=== context ==="
grep -n "No rule to make target" "$L" | tail -1 | cut -d: -f1 | while read n; do sed -n "$((n-3)),$((n+2))p" "$L"; done
echo "=== where did the module land? ==="
find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64 -maxdepth 6 -type d -name "SimpleFbDxe" 2>/dev/null | head -5