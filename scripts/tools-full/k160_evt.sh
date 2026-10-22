#!/usr/bin/env bash
set -e
VEN=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
[ -s /tmp/usbfn.asm ] || llvm-objdump -d "$VEN" > /tmp/usbfn.asm
echo "=== vendor around 0x8b80-0x8c60 (GEVNTSIZ/ADDR/COUNT setup) ==="
sed -n '/^ *8b80:/,/^ *8c60:/p' /tmp/usbfn.asm
echo
echo "=== reference patch: GEVNTSIZ / DEVTEN / DCFG lines ==="
P=/mnt/d/本地项目-01/_refs/ios-vermeer-lab/xnu/patches/0073-sweet-usb-device-ep0.patch
[ -f "$P" ] || P=/mnt/d/本地项目-01/_refs/ios-vermeer-lab/xnu/patches/0073-sweet-usb-device-ep0.patch
grep -nE 'GEVNTSIZ|GEVNTADR|DEVTEN|DCFG|DALEPENA|DEPSTARTCFG|SETEPCONFIG|STARTTRANSFER|EVT_EN|INTMASK' "$P" | head -60
