#!/usr/bin/env bash
echo "=== _refs all files: USB3_PHY_GDSCR / PRIM_BCR / CBCR ==="
grep -rInE 'USB3_PHY_GDSCR|USB30_PRIM_BCR|USB30_PRIM_CBCR|USB3_PHY_PRIM|QUSB2PHY_PRIM_BCR' /mnt/d/本地项目-01/_refs 2>/dev/null | head -30

echo
echo "=== uefi tree (all) for USB30/ USB3_PHY / QUSB2 clock names ==="
cd /root/k70/uefi
grep -rIlE 'usb30_prim|usb3_phy|qusb2phy' . 2>/dev/null | head -20

echo
echo "=== ClockDxe strings (clock names / usb) ==="
CD=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.efi
ls -l "$CD" 2>/dev/null
strings -a "$CD" 2>/dev/null | grep -iE 'usb30_prim|usb3_phy|qusb2phy|gdscr|cbcr|bcr' | head -40

echo
echo "=== UsbConfigDxe strings (gcc/qusb2 names) ==="
UC=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.efi
strings -a "$UC" 2>/dev/null | grep -iE 'gcc_|usb30|usb3_phy|qusb2|gdscr|cbcr|bcr' | head -40

echo
echo "=== keys93 fd available? ==="
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/ | grep -i keys9 | head -10
