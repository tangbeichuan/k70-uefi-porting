#!/bin/bash
# keys147: GUID inventory + Locate/Install sites for USB device-mode drivers
set -u
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
T=/mnt/d/本地项目-01/_tools
L=$T/usb147_proto.log
: > $L
for n in UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbInitDxe UsbConfigDxe UsbPwrCtrlDxe; do
  f=$(ls $B/$n/*.patched.efi 2>/dev/null | head -1)
  [ -z "$f" ] && f=$B/$n/$n.efi
  echo "################ $n ($f)" >> $L
  echo "---- dec-known GUID inventory ----" >> $L
  python3 $T/guid_match.py "$f" >> $L 2>&1 || true
  echo "---- LocateProtocol / OpenProtocol sites ----" >> $L
  python3 $T/usb145_proto.py "$f" >> $L 2>&1 || true
done
tail -300 $L
