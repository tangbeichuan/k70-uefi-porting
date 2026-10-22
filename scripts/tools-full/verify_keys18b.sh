#!/usr/bin/env bash
set -u
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64
echo "=== modules matching Sec / Pei === "
ls -1 "$B" | grep -iE '^(sec|pei|silicium)' | head -20
echo "=== grep 'Info Blk' (real PlatformPei.c string) in SEC-ish binaries ==="
for f in "$B"/*.efi; do
    n=$(basename "$f")
    c=$(grep -c -a 'Info Blk' "$f" 2>/dev/null || echo 0)
    if [ "$c" != "0" ]; then echo "  $n -> $c"; fi
done
echo "=== 'DtbExtension' / 'XblHob' strings anywhere in AARCH64 ==="
grep -l -a 'Failed to Locate' "$B"/*.efi 2>/dev/null | head
