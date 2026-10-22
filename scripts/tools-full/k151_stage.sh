#!/bin/bash
# which build artifacts contain "Loading DxeCore" and "MMU: enabled"
cd /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64
echo "== artifacts containing 'Loading DxeCore' =="
grep -rla 'Loading DxeCore' --include='*.efi' --include='*.dll' . 2>/dev/null | head -20
echo "== artifacts containing 'MMU: enabled' =="
grep -rla 'MMU: enabled' --include='*.efi' --include='*.dll' . 2>/dev/null | head -20
echo "== Silicium Sec source files =="
ls -la /root/k70/uefi/Silicon/Silicium/SiliciumPkg/Sec/ 2>/dev/null
echo "== grep source for the two strings =="
grep -rn "MMU: enabled\|Loading DxeCore" /root/k70/uefi/Silicon /root/k70/uefi/EmbeddedPkg /root/k70/uefi/MdeModulePkg /root/k70/uefi/ArmPkg 2>/dev/null | head -20
