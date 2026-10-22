set +e
X=/tmp/guid-keys122.xref
echo "=== LogDisk in FV? ==="; grep -i 'LogDisk' "$X" || echo "  MISSING"
echo "=== USB device drivers in FV? ==="
for g in UsbInitDxe UsbDeviceDxe UsbfnDwc3Dxe UsbMsdDxe UsbPwrCtrlDxe UsbConfigDxe UsbBusDxe; do
  if grep -qi "$g" "$X"; then echo "  KEEP $g"; else echo "  drop $g"; fi
done