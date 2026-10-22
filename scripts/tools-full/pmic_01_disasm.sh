#!/bin/bash
set -e
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi
mkdir -p /tmp/pmic
llvm-objdump -d "$EFI" > /tmp/pmic/pmic.asm 2>/dev/null || true
wc -l /tmp/pmic/pmic.asm
# PE section headers via llvm-readobj
llvm-readobj --sections "$EFI" > /tmp/pmic/sections.txt 2>/dev/null || true
cat /tmp/pmic/sections.txt | head -120
# whole-file hexdump for data area analysis
xxd -g1 "$EFI" > /tmp/pmic/pmic.hex
echo "=== strings with file offsets (printable >=5) ==="
strings -t x -n 5 "$EFI" > /tmp/pmic/strings.txt
wc -l /tmp/pmic/strings.txt
echo done
