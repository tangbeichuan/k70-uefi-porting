#!/usr/bin/env bash
set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe
echo "=== dir ==="
ls -l "$D"
echo "=== inf ==="
cat "$D/PmicDxe.inf"
echo "=== which files anywhere have sha 49394af1 (patched) / e67003c5 (stock) ==="
cd /root/k70/uefi
find . -name 'PmicDxe*.efi' -type f 2>/dev/null | while read f; do
  s=$(sha256sum "$f" | cut -c1-16)
  echo "$s  $f"
done
