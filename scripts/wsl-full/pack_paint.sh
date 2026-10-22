#!/usr/bin/env bash
# Package the already-built paint firmware (do not rebuild).
set -euo pipefail
UEFI=/root/k70/uefi
OUT=/mnt/d/本地项目-01/K70-UEFI-build
FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
IMG=$UEFI/Mu-vermeer.img

cp "$FD"  "$OUT/SILICIUM_UEFI-paint.fd"
cp "$IMG" "$OUT/Mu-vermeer-paint.img"

python3 /mnt/d/本地项目-01/_k70port_extract/package_v4.py \
  --fd "$OUT/SILICIUM_UEFI-paint.fd" \
  --shim "$OUT/BootShim-192.bin" \
  --out "$OUT/Mu-vermeer-paint-v4.img"

echo "=== paint driver inside the FD? ==="
python3 /mnt/d/本地项目-01/_k70port_extract/list_fd_modules2.py "$OUT/SILICIUM_UEFI-paint.fd" > /tmp/paint_mods.txt 2>&1 || true
grep -ci 'module' /tmp/paint_mods.txt || true
grep -i -E 'paint|SimpleFb|GraphicsConsole|SimpleTextIn' /tmp/paint_mods.txt || true
echo "--- total FFS records ---"
grep -c -i 'FFS\|module' /tmp/paint_mods.txt || true

echo "=== reverse check of the v1 image ==="
python3 /mnt/d/本地项目-01/_k70port_extract/verify_img.py "$OUT/Mu-vermeer-paint.img" "$OUT/Mu-vermeer-paint-v4.img" 2>&1 | tail -30 || \
  python3 /mnt/d/本地项目-01/_k70port_extract/verify_img.py "$OUT/Mu-vermeer-paint.img" 2>&1 | tail -20

cd "$OUT" && sha256sum SILICIUM_UEFI-paint.fd Mu-vermeer-paint.img Mu-vermeer-paint-v4.img
