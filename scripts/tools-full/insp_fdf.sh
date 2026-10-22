set +e
sed -n '95,115p' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
echo "=== FdtBlob ==="
ls -l /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/ | cat
echo "=== APRIORI provider? ==="
grep -n 'VermeerDtbExtnDxe\|VermeerUfsMapDxe\|VermeerSmmuStub' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc