#!/bin/bash
# usb146_anchor2.sh -- code around UsbConfigDxe string refs 0x12c20 (usb_repeater_init)
# and 0x12c6b (WRITING), then indirect calls near it
set -u
TO=/mnt/d/本地项目-01/_tools
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd
python3 $TO/cf146e.py "$FD" /tmp/ucfg145.efi >/dev/null
E=/tmp/ucfg145.efi
llvm-objdump -d "$E" > /tmp/u145.asm
echo "===== refs to #0xc20 (usb_repeater_init str) ====="
grep -n -B3 -A3 "#0xc20$" /tmp/u145.asm | head -40
echo
echo "===== refs to #0xc6b (WRITING str) ====="
grep -n -B4 -A4 "#0xc6b$" /tmp/u145.asm | head -40
echo
echo "===== refs to #0xc33 (tuning_allowed) ====="
grep -n -B3 -A3 "#0xc33$" /tmp/u145.asm | head -30
