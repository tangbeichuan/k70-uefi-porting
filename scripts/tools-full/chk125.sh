set +e
X=/tmp/guid-keys125.xref
for g in UsbfnDwc3 UsbDeviceDxe UsbMsdDxe UsbPwrCtrl LogDisk; do
  if grep -qi "$g" "$X"; then echo "  KEEP $g"; else echo "  ---- $g ABSENT"; fi
done
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys125.img