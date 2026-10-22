set +e
grep -i 'UsbfnDwc3\|UsbDeviceDxe' /tmp/guid-keys122.xref || echo "STILL ABSENT"