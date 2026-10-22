#!/bin/bash
set -u
TO=/mnt/d/本地项目-01/_tools
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd
E=/tmp/ucfg145.efi
[ -s "$E" ] || python3 $TO/cf146e.py "$FD" "$E" >/dev/null
for r in "0x1600 0x1790" "0x3040 0x3160" "0xbc40 0xbd80" "0xe7c0 0xe8f0"; do
  set -- $r
  echo "===== $1 - $2 ====="
  llvm-objdump -d --start-address=$1 --stop-address=$2 "$E" | sed -n '/Disassembly/,$p'
done
