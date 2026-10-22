#!/usr/bin/env bash
set -e
H=/root/k70/uefi/Silicon/Samsung/SamsungPkg/Include/Device/Dwc3.h
echo "=== Dwc3.h exists? ==="; ls -l "$H"
echo "=== DEVTEN / GEVNT / DEPCMD / DALEPENA defines ==="
grep -nE 'DEVTEN|GEVNT|DEPCMD|DALEPENA|DEPSTARTCFG|SETEPCONFIG|STARTTRANSFER|XFERCOMPLETE|CMDACT|CSPLIT|DCFG|DCTL' "$H" | head -80
echo
echo "=== header EP0 / 0xC80 / 0xC10 offsets ==="
grep -nE '0xC8|0xC1|0xC40|0xC70|0xC20' "$H" | head -50
echo
echo "=== vendor UsbfnDwc3Dxe: 0xC80C / 0xC800 / 0xC100 / 0xC104 immediates ==="
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
[ -s /tmp/usbfn157.asm ] || llvm-objdump -d "$E" > /tmp/usbfn157.asm
grep -nE '#0xc80[0-9a-f]|#0xc81[0-9a-f]|#0xc10[0-9a-f]' /tmp/usbfn157.asm | head -40
