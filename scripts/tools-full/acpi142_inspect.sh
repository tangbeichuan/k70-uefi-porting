#!/bin/bash
set -e
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== vermeer.fdf 125-160 ==="
sed -n '125,160p' $PKG/vermeer.fdf | cat -n | sed 's/^/  /'
echo "=== dsc AcpiTableDxe / AcpiTables 引用 ==="
grep -n -i "acpi" $PKG/vermeer.dsc | head -20
echo "=== SiliciumPkg.dsc.inc AcpiTableDxe ==="
grep -n "AcpiTableDxe\|AcpiPlatformDxe" /root/k70/uefi/SiliciumPkg/SiliciumPkg.dsc.inc | head
echo "=== 其它平台 fdf 参考 ==="
grep -n "AcpiTableDxe" /root/k70/uefi/Platforms/Qcom/*/*.fdf 2>/dev/null | head
