#!/bin/bash
M=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/SiliciumPkg/Sec/Sec/DEBUG/Sec.map
S=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Ffs/9AFFB503-E643-4141-8B90-17E8588B1D35Sec/9AFFB503-E643-4141-8B90-17E8588B1D35.efi
echo "== map =="
ls -l "$M" 2>/dev/null || echo "no map"
grep -oE 'PlatformPeiLib[A-Za-z]*|PlatformPei\.c|PlatformPeiLibNull' "$M" 2>/dev/null | sort | uniq -c | head -10
grep -c 'XblProtocols' "$M" 2>/dev/null
echo "== Sec.efi =="
ls -l "$S" 2>/dev/null || echo "no efi"
if [ -f "$S" ]; then
  for pat in 'Info Blk' 'Info_Blk' 'FD Reserved' 'FD_Reserved' 'XblProtocols' 'Scheduler'; do
    printf '%-14s %s\n' "$pat" "$(strings "$S" | grep -c "$pat")"
  done
fi
echo "== which lib dirs were built recently =="
ls -ld /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/SiliciumNullPkg/Library/PlatformPeiLibNull 2>/dev/null
ls -ld /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/QcomPkg/Library/PlatformPeiLib 2>/dev/null
