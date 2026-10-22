set +e
grep -iE "UsbConfig|UsbInit|PmicVerStub|UsbMsd|Usbfn" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref 2>/dev/null | head -20
echo "--- vermeer dec/inf names for usbconfig ---"
ls /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/ | grep -i "usb" | head
echo "--- apriori usb lines ---"
grep -in "usb" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc | head -20