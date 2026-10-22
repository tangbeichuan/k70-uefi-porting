#!/bin/bash
D=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG
echo "=== build dir ==="
ls -l "$D"
echo "=== efi sections ==="
llvm-objdump -h "$D/VermeerMenuDxe.efi" 2>&1 | head -20
echo "=== disasm 0x1B00-0x1D80 (VMA) ==="
llvm-objdump -d --start-address=0x1B00 --stop-address=0x1D80 "$D/VermeerMenuDxe.efi" 2>&1 | head -140
