set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
echo "=== UsbDeviceDxe.inf ==="; cat "$D/UsbDeviceDxe/UsbDeviceDxe.inf"
echo "=== UsbfnDwc3Dxe.inf ==="; cat "$D/UsbfnDwc3Dxe/UsbfnDwc3Dxe.inf"
echo "=== depex ==="; xxd "$D/UsbDeviceDxe/UsbDeviceDxe.depex" | head -3; xxd "$D/UsbfnDwc3Dxe/UsbfnDwc3Dxe.depex" | head -6