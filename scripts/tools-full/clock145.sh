#!/bin/bash
# clock145.sh -- how UsbConfigDxe obtains gEfiClockProtocolGuid and what happens
# when it is missing (keys144 question: should "ClockProtocol unavailable" go away?).
set -u
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
ASM=/tmp/clock145.asm
llvm-objdump -d "$E" > "$ASM"

echo "===== instructions that build the address of the clock GUID (0x130f8) ====="
grep -n -E "add\s+x[0-9]+, x[0-9]+, #0xf8" "$ASM" | head
echo
echo "===== context around each clock-GUID load ====="
grep -n -E "#0xf8$" "$ASM" | head
echo
echo "===== string refs to \"%a: ClockProtocol unavailable\" (0x11146) / InitUsbClocks (0x11106) / DisableUsbClocks (0x11135) ====="
grep -n -E "add\s+x[0-9]+, x[0-9]+, #0x146|add\s+x[0-9]+, x[0-9]+, #0x135|add\s+x[0-9]+, x[0-9]+, #0x106" "$ASM"
echo
echo "===== full window for each hit (search for adrp 0x11000 nearby) ====="
for off in 0x146 0x135 0x106 0x114; do
  echo "--- add #$off ---"
  grep -n -E "add\s+x[0-9]+, x[0-9]+, #$off" "$ASM" | head -3
done
echo
echo "===== all 'adrp xN, 0x11000' sites with the next add ====="
grep -n -A2 -E "adrp\s+x[0-9]+, 0x11000" "$ASM" | head -60
