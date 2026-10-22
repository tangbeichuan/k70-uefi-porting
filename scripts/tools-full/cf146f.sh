#!/bin/bash
set -u
python3 /mnt/d/本地项目-01/_tools/cf146e.py /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys144.fd /tmp/ucfg144.efi
python3 /mnt/d/本地项目-01/_tools/cf146e.py /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys143.fd /tmp/ucfg143.efi
echo "=== keys144 UsbConfigDxe 0x3F5C-0x4010 (patched image) ==="
llvm-objdump -d --start-address=0x3f5c --stop-address=0x4010 /tmp/ucfg144.efi
echo
echo "=== the branch at 0x3fa8 decoded ==="
llvm-objdump -d --start-address=0x3fa4 --stop-address=0x3fac /tmp/ucfg144.efi
echo
echo "=== same for keys143 ==="
llvm-objdump -d --start-address=0x3fa4 --stop-address=0x3fac /tmp/ucfg143.efi
