#!/usr/bin/env bash
# Copy a few PE images out of the build tree plus the freshly built paint driver
# so the Windows side can compare their PE alignment fields.
set -euo pipefail
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
D=/mnt/d/本地项目-01/_k70port_extract
n=0
while IFS= read -r f; do
  n=$((n+1))
  cp "$f" "$D/ref_$n.efi"
  echo "ref_$n.efi <- $f"
done < <(find "$B" \( -name 'SimpleFbDxe.efi' -o -name 'GraphicsConsoleDxe.efi' -o -name 'PrintDxe.efi' -o -name 'BdsDxe.efi' \) -path '*/DEBUG/*' | head -4)
ls -l "$D"/ref_*.efi
