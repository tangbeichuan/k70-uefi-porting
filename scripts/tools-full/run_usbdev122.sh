set +e
python3 /mnt/d/本地项目-01/_tools/patch_usbdev122.py; echo rc=$?
grep -n 'UsbfnDwc3\|UsbDevice' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc