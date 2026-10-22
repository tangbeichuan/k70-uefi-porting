#!/bin/bash
set -e
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe
echo "=== HALIOMMUDxe.inf ==="
cat $D/HALIOMMUDxe.inf
echo "=== depex hex ==="
xxd -p $D/HALIOMMUDxe.depex | tr -d '\n'; echo
echo "=== files ==="
ls -l $D
echo "=== HALIOMMU in vermeer DXE/APRIORI/RAW/dsc/fdf ==="
grep -n "HALIOMMU\|HalIommu\|Iommu" $PKG/Include/DXE.inc $PKG/Include/APRIORI.inc $PKG/Include/RAW.inc $PKG/vermeer.dsc $PKG/vermeer.fdf 2>/dev/null | head -20
echo "=== HALIOMMU in build script drop harness ==="
grep -n "iommu\|halio" /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys142.sh | head
echo "=== Guid.xref HALIOMMU? ==="
grep -i "iommu" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref || echo "  (absent)"
