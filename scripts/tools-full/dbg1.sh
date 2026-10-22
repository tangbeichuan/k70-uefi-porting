#!/bin/bash
cd /root/k70/uefi || exit 1
echo "=== assert site ==="
grep -rn 'Format != ((void \*) 0)\|Format != NULL' --include=*.c . 2>/dev/null | grep -i debuglib | head -10
echo
echo "=== found DebugLib.c files ==="
grep -rln 'ASSERT (Format' --include=DebugLib.c . 2>/dev/null | head -10
echo
echo "=== NpaDxe depex (text form if any) ==="
ls -l Binaries/vermeer/QcomPkg/Drivers/NpaDxe/
echo
echo "=== NpaDxe.inf ==="
cat Binaries/vermeer/QcomPkg/Drivers/NpaDxe/NpaDxe.inf 2>/dev/null | head -60
echo
echo "=== keys12 keep list from DEBUG build FVMAIN (driver order) ==="
grep -o '0x[0-9A-F]* [0-9A-F-]* [A-Za-z0-9_]*' Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt 2>/dev/null | head -60
