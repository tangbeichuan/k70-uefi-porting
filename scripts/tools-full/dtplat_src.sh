#!/bin/bash
U=/root/k70/uefi
echo "=== DtPlatformDxe source files ==="
ls -l $U/EmbeddedPkg/Drivers/DtPlatformDxe/ 2>/dev/null
echo
echo "=== which GUID does it look for? ==="
grep -rn "GUID\|Guid\|FvFindFile\|GetSectionFromAnyFv\|LocateFv\|Not Found" $U/EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.c 2>/dev/null | head -40
echo
echo "=== .inf ==="
cat $U/EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf 2>/dev/null
echo
echo "=== DEC/DSC entry for the DT blob guid ==="
grep -rn "25462CDA\|25462cda" $U/EmbeddedPkg $U/MdePkg $U/MdeModulePkg --include=*.dec --include=*.inf --include=*.h --include=*.dsc 2>/dev/null | head -20
