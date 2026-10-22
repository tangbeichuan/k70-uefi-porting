set +e
A=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
grep -n -i 'usbconfig\|usbinit\|usbmsd\|usbdevice\|usbfn\|VermeerLogDisk\|VermeerMenu' "$A" | head -20