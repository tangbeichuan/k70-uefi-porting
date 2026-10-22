set +e
python3 /mnt/d/本地项目-01/_tools/patch_usbdev122.py; echo "rc=$?"
echo "=== after ==="
grep -n 'UsbfnDwc3\|UsbDeviceDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
grep -n 'UsbfnDwc3\|UsbDeviceDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/DXE.inc