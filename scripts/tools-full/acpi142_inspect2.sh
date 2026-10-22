#!/bin/bash
set -e
echo "=== find dsc.inc ==="
find /root/k70/uefi -maxdepth 3 -name "*.dsc.inc" | head
echo "=== grep AcpiTableDxe in dsc/dsc.inc ==="
grep -rn "AcpiTableDxe" /root/k70/uefi --include=*.dsc --include=*.inc 2>/dev/null | grep -v Build/ | head -20
echo "=== built efi ==="
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/AcpiTableDxe.efi 2>/dev/null || echo MISSING
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/AcpiPlatformDxe.efi 2>/dev/null || echo "AcpiPlatformDxe MISSING"
echo "=== [FV.FvMain] header above ACPI block ==="
awk 'NR>=1 && NR<=140 && /^\[/ {print NR": "$0}' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
