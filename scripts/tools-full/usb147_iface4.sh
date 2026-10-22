#!/bin/bash
set -u
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
if [ ! -s /tmp/ucfg_if2.asm ]; then llvm-objdump -d --no-show-raw-insn "$EFI" > /tmp/ucfg_if2.asm; fi
echo "== 0x4c60-0x4ce0 =="
sed -n '/    4c60:/,/    4ce0:/p' /tmp/ucfg_if2.asm
echo "== 0x4e00-0x4e90 =="
sed -n '/    4e00:/,/    4e90:/p' /tmp/ucfg_if2.asm
echo "== 0x4b80-0x4c60 (context before 4c8c) =="
sed -n '/    4b80:/,/    4c60:/p' /tmp/ucfg_if2.asm
