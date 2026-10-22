#!/usr/bin/env bash
set -e
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi
llvm-objdump -d "$E" > /tmp/menu159.asm
echo "=== immediate pieces for 0x0A60xxxx ==="
grep -nE '#0xa60|#0x60, lsl|lsl #16' /tmp/menu159.asm | head -40
echo
echo "=== lines with 0xc70/0xc80/0xc40 immediates ==="
grep -nE '#0xc70[0-9a-f]|#0xc80[0-9a-f]|#0xc40[0-9a-f]' /tmp/menu159.asm | head -40
echo
echo "=== functions (symbols) ==="
llvm-objdump -t "$E" 2>/dev/null | grep -iE 'Usb159|Usb159Init|Usb159Poll' | head
echo
echo "=== count of bl to Usb159* via disasm labels ==="
grep -cE 'Usb159' /tmp/menu159.asm || true
