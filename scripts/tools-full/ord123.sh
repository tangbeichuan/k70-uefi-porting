set +e
python3 /mnt/d/本地项目-01/_tools/patch_order123.py
echo "=== APRIORI around menu ==="
grep -n 'UsbfnDwc3\|UsbDeviceDxe\|LogDisk\|VermeerMenuDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== DXE.inc ==="
grep -n 'UsbfnDwc3\|UsbDeviceDxe\|LogDisk\|VermeerMenuDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/DXE.inc