set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
echo "=== vendor USB drivers ==="
ls -1 "$D" | grep -i usb
echo "=== any CDC/ACM/Serial class drivers in tree ==="
ls -1 "$D" | grep -i -E 'cdc|acm|serial|usbfn' 
echo "=== Mu basecore USB device-side ==="
ls -1 /root/k70/uefi/Mu_Basecore/MdeModulePkg/Bus/Usb/ 2>/dev/null
echo "=== usbfn / cdc libs in tree ==="
find /root/k70/uefi -maxdepth 4 -iname '*usbfn*' -o -maxdepth 4 -iname '*cdc*' | head -20