#!/bin/bash
# grep_transact.sh -- where does the ASCII string "transact" live?
set -u
echo "===== 1) xbl_ufs.dtb ====="
grep -abo "transact" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb || echo "  (none)"
echo
echo "===== 2) FVMAIN.Fv (build output, uncompressed FV) ====="
grep -abo "transact" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv || echo "  (none)"
echo
echo "===== 3) all prebuilt QcomPkg binaries ====="
for f in $(find /root/k70/uefi/Binaries/vermeer -name "*.efi" | sort); do
  hits=$(grep -abo "transact" "$f" | head -3 | tr '\n' ' ')
  [ -n "$hits" ] && echo "  $f :: $hits"
done
echo
echo "===== 4) our own drivers (build output) ====="
for f in $(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64 -name "Vermeer*.efi" -o -name "*.efi" | sort); do
  hits=$(grep -abo "transact" "$f" 2>/dev/null | head -2 | tr '\n' ' ')
  [ -n "$hits" ] && echo "  $f :: $hits"
done | head -30
echo
echo "===== 5) source tree (port-drivers + _tools) ====="
grep -rn "transact" /mnt/d/本地项目-01/_k70port_extract/port-drivers/ 2>/dev/null | head -10
grep -rln "transact" /mnt/d/本地项目-01/_tools/*.c /mnt/d/本地项目-01/_tools/*.h 2>/dev/null | head
echo
echo "===== 6) context: bytes around each FVMAIN hit ====="
for off in $(grep -abo "transact" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv | cut -d: -f1 | head -5); do
  s=$((off-32)); [ $s -lt 0 ] && s=0
  echo "--- FVMAIN offset $off ---"
  dd if=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv bs=1 skip=$s count=96 2>/dev/null | strings -t d | head -5
done
