#!/usr/bin/env bash
set -e
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi
[ -f "$E" ] || E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3/UsbfnDwc3Dxe.efi
ls -l "$E"
llvm-objdump -d "$E" > /tmp/usbfn157.asm
echo "=== GEVNT / DEVTEN / DALEPENA immediates in UsbfnDwc3Dxe ==="
grep -nE '#0xc40[0-9a-f]|#0xc70[0-9a-f]|#0xc72[0-9a-f]|#0xc71[0-9a-f]' /tmp/usbfn157.asm | head -40
echo "=== context: GEVNTADR/GEVNTSIZ candidates ==="
grep -nE '#0xc40[048c]' /tmp/usbfn157.asm | head -8 | while read -r L; do
  n=${L%%:*}; echo "--- line $n ---"; sed -n "$((n-4)),$((n+4))p" /tmp/usbfn157.asm
done
