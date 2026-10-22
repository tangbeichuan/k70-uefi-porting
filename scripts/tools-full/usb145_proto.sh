#!/bin/bash
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
for M in UsbConfigDxe UsbInitDxe UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbBusDxe UsbPwrCtrlDxe; do
  F=$(ls $B/$M/$M.patched.efi 2>/dev/null | head -1); [ -z "$F" ] && F=$B/$M/$M.efi
  python3 /mnt/d/本地项目-01/_tools/usb145_proto.py "$F"
done 2>&1
