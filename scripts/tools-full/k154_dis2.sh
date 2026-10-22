#!/bin/bash
D=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG
echo "=== _ModuleEntryPoint 0x1AEC..0x1D00 ==="
llvm-objdump -d --start-address=0x1C00 --stop-address=0x1D00 "$D/VermeerMenuDxe.efi"
echo "=== Say / DebugPrint 0x1D00..0x1E68 ==="
llvm-objdump -d --start-address=0x1D00 --stop-address=0x1E68 "$D/VermeerMenuDxe.efi"
