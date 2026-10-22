#!/usr/bin/env bash
# k162_dis.sh -- dump keys162 Menu register accesses for the report.
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
echo "EFI: $E"
llvm-objdump -d "$E" > /tmp/m162.asm
echo "--- movk with 0xa6 (DWC3 base high) ---"
grep -nE 'movk\s+w[0-9]+, #0xa6' /tmp/m162.asm | head -10
echo "--- accesses via register offsets (0xc0xx window) ---"
grep -nE '#0xc(00|04|08|0c|10|12|20|1c|70|74|7c|40)|#0xc40c|#0xc408|#0xc404|#0xc400|#0xc704|#0xc708|#0xc70c|#0xc200|#0xc110|#0xc120' /tmp/m162.asm | head -60
echo "--- event drain loop (Usb162Poll symbol) ---"
grep -n 'Usb162Poll\|Usb162Stat\|Usb162Init\|Usb162Wr\|Usb162Rd' /tmp/m162.asm | head -30
