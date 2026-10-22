#!/bin/bash
f=$(find /root/k70/uefi -name 'CompareGuid.c' -not -path '*/Build/*' | head -3)
echo "files: $f"
for x in $f; do
  echo "=== $x ==="
  grep -n "return" "$x" | head -5
done
echo "=== callers check: XblProtocols uses != 0 ==="
grep -n "CompareGuid" /root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/XblProtocols.c
