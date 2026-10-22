set +e
AP=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
cp "$AP" /tmp/APRIORI.now.bak
python3 /mnt/d/本地项目-01/_tools/patch_usbvbus147.py
echo "=== order ==="
grep -n 'VermeerUsbVbusDxe\|UsbfnDwc3Dxe\|UsbDeviceDxe\|VermeerLogDiskDxe\|VermeerMenuDxe' "$AP"
cp /tmp/APRIORI.now.bak "$AP"
echo "restored"