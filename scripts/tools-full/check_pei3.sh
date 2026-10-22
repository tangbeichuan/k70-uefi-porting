#!/bin/bash
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64
echo "== null lib build dir =="
ls -ld "$B/SiliciumNullPkg/Library/PlatformPeiLibNull" 2>/dev/null || echo "  absent"
find "$B/SiliciumNullPkg" -name '*.obj' -newermt '-20 minutes' 2>/dev/null | head -5
echo "== Sec.map =="
M=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/SiliciumPkg/Sec/Sec/DEBUG/Sec.map
ls -l "$M"
grep -c 'SiliciumNullPkg' "$M" || true
grep -c 'QcomPkg/Library/PlatformPeiLib' "$M" || true
echo "== Sec.efi strings =="
S=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Ffs/9AFFB503-E643-4141-8B90-17E8588B1D35Sec/9AFFB503-E643-4141-8B90-17E8588B1D35.efi
ls -l "$S"
for pat in 'Info Blk' 'FD Reserved' 'XblProtocols' 'Failed to locate memory region'; do
  printf '%-28s %s\n' "$pat" "$(strings "$S" | grep -c "$pat")"
done
