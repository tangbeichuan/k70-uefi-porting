#!/bin/bash
set -u
TO=/mnt/d/本地项目-01/_tools
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd
E=/tmp/ucfg145.efi
[ -s "$E" ] || python3 $TO/cf146e.py "$FD" "$E" >/dev/null
[ -s /tmp/u145.asm ] || llvm-objdump -d "$E" > /tmp/u145.asm
python3 $TO/usb146_refs.py 2>&1 | head -220
