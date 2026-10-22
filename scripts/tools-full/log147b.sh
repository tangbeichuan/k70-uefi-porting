set +e
grep -n "error\|Error" /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | grep -i "vermmer\|VermeerUsbVbus\|usbvbus" | head -20
echo "=== tail 40 ==="
tail -40 /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt