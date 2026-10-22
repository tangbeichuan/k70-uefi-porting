#!/bin/bash
S=/mnt/d/本地项目-01/_k70port_extract/_upstream/UniXNU__uefi-sheng
echo "=== sheng.fdf: dt / FdtBlob / DtPlatform ==="
grep -in "fdt\|dtb\|FdtBlob\|DtPlatform\|25462CDA" "$S/Platforms/Xiaomi/shengPkg/sheng.fdf" || echo "none"
echo
echo "=== sheng.dsc: PlatformPeiLib / DtbExtn / Fdt ==="
grep -in "PlatformPeiLib\|DtbExtn\|Fdt\|MemoryMapLib" "$S/Platforms/Xiaomi/shengPkg/sheng.dsc" || echo "none"
echo
echo "=== any dtb/dts inside the tree? ==="
find "$S" -iname '*.dtb' -o -iname '*.dts' -o -iname '*.dtbo' | head -20
echo
echo "=== PORTING.md head ==="
head -40 "$S/Platforms/Xiaomi/shengPkg/PORTING.md"
