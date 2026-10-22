set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
echo "=== VBUS driver in Guid.xref? ==="
grep -i '4A8E2C71' "$B/FV/Guid.xref" || echo "NOT IN FV"
echo "=== APRIORI order around UsbConfig/Usbfn ==="
grep -n 'VermeerUsbVbusDxe\|UsbfnDwc3Dxe\|UsbDeviceDxe\|UsbConfigDxe\|VermeerLogDiskDxe\|VermeerMenuDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== img size ==="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys147b.img