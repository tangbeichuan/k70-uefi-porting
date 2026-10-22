set +e
dtc -I dtb -O dts /mnt/d/_k70tmp/xbl_ufs_57.dtb 2>/dev/null > /tmp/ufs57.dts || echo dtc-fail
wc -l /tmp/ufs57.dts
echo "=== iort node ==="
grep -n "iort" /tmp/ufs57.dts | head
awk '/iort \{/,/^\t\t};/' /tmp/ufs57.dts | head -60