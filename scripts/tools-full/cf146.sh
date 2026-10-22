#!/bin/bash
# cf146.sh -- exact control flow of UsbConfigDxe 0x3F60-0x4050 (IOMMU init),
# pristine vs keys143+ patch, plus which branch targets exist around 0x3FE8.
set -u
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi   # pristine (restored after build)
echo "===== UsbConfigDxe pristine 0x3F5C-0x4054 ====="
llvm-objdump -d --start-address=0x3f5c --stop-address=0x4054 "$E"
echo
echo "===== all branch targets referencing 0x3fe8 / 0x3ff0 / 0x41c4 / 0x3fb0 (whole .text) ====="
llvm-objdump -d "$E" > /tmp/cf146.asm
grep -n -E "0x3fe8|0x3ff0|0x41c4|0x3fb0|0x4020|0x4040" /tmp/cf146.asm | head -40
echo
echo "===== instructions at exactly 0x3fe0..0x4010 (raw) ====="
grep -E "^\s+3fe[0-9a-f]:|^\s+3ff[0-9a-f]:|^\s+400[0-9a-f]:|^\s+401[0-9a-f]:" /tmp/cf146.asm
