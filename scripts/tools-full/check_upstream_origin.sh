#!/bin/bash
U=/root/k70/uefi
echo "=== does the vermeer build reference UniXNU at all? ==="
grep -ril "unixnu" "$U/Platforms/Xiaomi/vermeerPkg" 2>/dev/null | head -20 || true
echo "--- dsc/fdf hits ---"
grep -rin "unixnu" "$U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc" "$U/Platforms/Xiaomi/vermeerPkg/vermeer.fdf" 2>/dev/null || echo "none"
echo
echo "=== upstream trees we keep for reference ==="
ls -1 /root/k70 2>/dev/null
ls -1 /mnt/d/本地项目-01/_k70port_extract/_upstream 2>/dev/null
echo
echo "=== vermeerPkg platform identity ==="
grep -rin "PlatformName\|PcdFirmwareVendor\|Project Silicium" "$U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc" 2>/dev/null | head -10
