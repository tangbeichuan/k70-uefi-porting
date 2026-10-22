#!/usr/bin/env bash
set -u
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64
echo "=== VermeerDtDumpDxe.efi ==="
ls -l "$B"/VermeerDtDumpDxe.efi 2>/dev/null || echo "  missing"
for s in "DTB EXTENSION HOB" "DTBExtn protocol Status" "vermeer device-tree dump"; do
    printf '  %-28s -> ' "$s"
    grep -c -a "$s" "$B"/VermeerDtDumpDxe.efi 2>/dev/null || echo 0
done
echo "=== PlatformPei.c compiled? ==="
grep -c 'PlatformPei\.c' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt || true
grep -o 'QcomPkg/Library/PlatformPeiLib/[A-Za-z]*\.c' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | sort -u
echo "=== linked into? ==="
grep -B2 -A2 'PlatformPeiLib' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | grep -iE 'Sec|PlatformPeiLib\.inf|Module' | head -10
