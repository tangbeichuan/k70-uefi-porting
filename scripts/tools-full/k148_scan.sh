#!/bin/bash
set -u
DTS=/mnt/d/本地项目-01/_tools/k148_xbl_ufs.dts
echo '===== DTS: 88e addrs / repeater / eusb / qmp ====='
grep -n -i -E '88e[0-9a-f]{3}|repeater|eusb|qmp|usb' "$DTS" | head -60
echo
echo '===== Binaries: who has usb_repeater strings ====='
cd /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers 2>/dev/null || cd /root/k70/uefi/Binaries/vermeer
for f in UsbConfigDxe/UsbConfigDxe.efi UsbConfigDxe/UsbConfigDxe.patched.efi UsbDeviceDxe/UsbDeviceDxe.efi UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi UsbInitDxe/UsbInitDxe.efi; do
  [ -f "$f" ] || continue
  echo "--- $f"
  strings -a "$f" | grep -i -E 'repeater|eusb2|qusb|qmp|tuning_allowed|WRITING' | head -12
done
echo
echo '===== other USB-ish driver dirs ====='
ls -d /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/*Usb* /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/*Phy* 2>/dev/null