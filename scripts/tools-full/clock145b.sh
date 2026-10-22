#!/bin/bash
# clock145b.sh -- inspect the clock-protocol acquisition path in UsbConfigDxe.
set -u
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
echo "===== 0x9b20-0x9bd0 (where GUID 0x130f8 is used) ====="
llvm-objdump -d --start-address=0x9b20 --stop-address=0x9bd0 "$E"
echo; echo "===== 0x7e80-0x7f40 (ClockProtocol unavailable / DisableUsbClocks) ====="
llvm-objdump -d --start-address=0x7e80 --stop-address=0x7f40 "$E"
echo; echo "===== 0x7ce0-0x7dc0 (InitUsbClocks) ====="
llvm-objdump -d --start-address=0x7ce0 --stop-address=0x7dc0 "$E"
echo; echo "===== 0x9b00-0x9b30 preamble ====="
llvm-objdump -d --start-address=0x9ae0 --stop-address=0x9b20 "$E"
echo; echo "===== strings near 0x11100-0x11180 ====="
strings -t x "$E" | awk 'strtonum("0x"$1)>=0x110e0 && strtonum("0x"$1)<=0x11190'
