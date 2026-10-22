set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "=== run_keys69.sh DROP ==="
sed -n '/DROP/,/]/p' run_keys69.sh | head -30
echo "=== Guid.xref 里 HALIOMMU / PmicDxe ==="
grep -iE 'halio|pmic' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref 2>/dev/null | head
echo "=== FV 报告里还有没有 HALIOMMU ==="
grep -iE 'halio' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Report.log 2>/dev/null | head -3
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/*.log 2>/dev/null | head