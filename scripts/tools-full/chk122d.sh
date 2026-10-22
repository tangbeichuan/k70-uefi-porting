set +e
X=/tmp/guid-keys122.xref
ls -l "$X"
grep -i 'UsbfnDwc3\|UsbDeviceDxe\|LogDisk' "$X" || echo "none found"
echo "=== apriori state now ==="
grep -n 'UsbfnDwc3\|UsbDeviceDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc