set +e
X=/tmp/guid-keys122.xref
for g in LogDisk UsbInitDxe UsbDeviceDxe UsbfnDwc3Dxe UsbMsdDxe UsbPwrCtrlDxe UsbConfigDxe UsbBusDxe UsbKbDxe UsbMassStorageDxe; do
  if grep -qi "$g" "$X"; then echo "  KEEP $g"; else echo "  ---- $g ABSENT"; fi
done