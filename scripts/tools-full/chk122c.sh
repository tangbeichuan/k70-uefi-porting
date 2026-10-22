set +e
P=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== APRIORI grep ==="; grep -n 'UsbfnDwc3\|UsbDeviceDxe' "$P/Include/APRIORI.inc"
echo "=== DXE.inc grep ==="; grep -n 'UsbfnDwc3\|UsbDeviceDxe' "$P/Include/DXE.inc" 2>/dev/null
echo "=== fdf grep ==="; grep -n 'UsbfnDwc3\|UsbDeviceDxe' "$P/vermeer.fdf" 2>/dev/null
echo "=== binaries exist? ==="
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbDeviceDxe/ 2>/dev/null
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/ 2>/dev/null