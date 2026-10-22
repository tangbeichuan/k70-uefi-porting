#!/bin/bash
U=/root/k70/uefi
echo "=== SimpleFbDxe / GOP producers in the tree ==="
find "$U" -maxdepth 6 -iname '*SimpleFb*' -o -maxdepth 6 -iname '*FbDxe*' 2>/dev/null | head -20
echo
echo "=== Mu_Basecore GraphicsOutput / UefiGop candidates ==="
find "$U/Mu_Basecore" -maxdepth 5 -type d -iname '*Graphics*' 2>/dev/null | head -20
echo
echo "=== do we already ship GraphicsConsole/ConSplitter/Vga? ==="
grep -Ei 'GraphicsConsole|ConSplitter|SimpleFb|Gop' "$U/Platforms/Xiaomi/vermeerPkg/vermeer.dsc" | head -20
echo
echo "=== upstream sheng dsc: how it enables SimpleFbDxe ==="
grep -rin 'SimpleFb\|GraphicsConsole\|Gop' /mnt/d/本地项目-01/_k70port_extract/_upstream/UniXNU__uefi-sheng/Platforms/Xiaomi/shengPkg/sheng.dsc /mnt/d/本地项目-01/_k70port_extract/_upstream/UniXNU__uefi-sheng/Platforms/Xiaomi/shengPkg/sheng.fdf | head -20
