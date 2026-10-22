#!/usr/bin/env bash
# Build the paint-enabled firmware variant (VERMEER_PAINT=1), keep the shipping
# configuration untouched, and publish both a v1 and a v4 container for it.
set -euo pipefail
export PATH=/root/k70/tools/bin:$PATH
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
VENV=/root/k70/venv
OUT=/mnt/d/本地项目-01/K70-UEFI-build
cd "$UEFI"

restore() { sed -i 's/^  VERMEER_PAINT                   = 1$/  VERMEER_PAINT                   = 0/' "$PKG/vermeer.dsc"; }
trap restore EXIT

sed -i 's/^  VERMEER_PAINT                   = 0$/  VERMEER_PAINT                   = 1/' "$PKG/vermeer.dsc"
grep -n 'VERMEER_PAINT' "$PKG/vermeer.dsc" | head -2

echo "=== building paint variant ==="
"$VENV/bin/python" build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -25

FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
IMG=$UEFI/Mu-vermeer.img          # build_uefi.py writes the image into the repo root
ls -l "$FD" "$IMG"

cp "$FD"  "$OUT/SILICIUM_UEFI-paint.fd"
cp "$IMG" "$OUT/Mu-vermeer-paint.img"

echo "=== v4 container for the paint firmware ==="
python3 /mnt/d/本地项目-01/_k70port_extract/package_v4.py \
  --fd "$OUT/SILICIUM_UEFI-paint.fd" \
  --shim "$OUT/BootShim-192.bin" \
  --out "$OUT/Mu-vermeer-paint-v4.img"

echo "=== module presence check ==="
python3 /mnt/d/本地项目-01/_k70port_extract/list_fd_modules2.py "$OUT/SILICIUM_UEFI-paint.fd" 2>/dev/null | grep -i -E 'paint|SimpleFb|GraphicsConsole' || \
  python3 /mnt/d/本地项目-01/_k70port_extract/list_fd_modules2.py "$OUT/SILICIUM_UEFI-paint.fd" | head -20

echo "=== shas ==="
cd "$OUT" && sha256sum SILICIUM_UEFI-paint.fd Mu-vermeer-paint.img Mu-vermeer-paint-v4.img
