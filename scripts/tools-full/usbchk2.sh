set +e
P=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== DXE.inc 里 usb ==="; grep -niE 'usb' $P/Include/DXE.inc | head
echo "=== APRIORI.inc 里 usb ==="; grep -niE 'usb' $P/Include/APRIORI.inc | head
echo "=== vermeer.dsc 里 InfBinaries/usb ==="; grep -niE 'usb' $P/vermeer.dsc | head
echo "=== fdf 里 usb ==="; grep -niE 'usb' $P/vermeer.fdf | head
echo "=== Guid.xref 里 usb（当前构建） ==="
grep -iE 'usb' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref | head -12