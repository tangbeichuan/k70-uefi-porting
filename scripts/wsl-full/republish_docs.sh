#!/usr/bin/env bash
# Refresh the "as-built" copies in K70-UEFI-build from the live WSL checkout, so
# the files the user reads are exactly the ones that produced the published
# images (the earlier publish happened before the DtPlatformDxe gating).
set +e
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
OUT=/mnt/d/本地项目-01/K70-UEFI-build

cp -f "$PKG/vermeer.dsc" "$PKG/vermeer.fdf" "$OUT/"
cp -f "$PKG/Library/MemoryMapLib/MemoryMapLib.c" "$PKG/Library/ConfigurationMapLib/ConfigurationMapLib.c" "$OUT/"
cp -f "$UEFI/Resources/Configs/vermeer.toml" "$OUT/"
cp -f /root/k70/build-default.log "$OUT/BUILDLOG_vermeerPkg.txt"
cp -f "$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/BUILD_REPORT.TXT" "$OUT/BUILD_REPORT.TXT" 2>/dev/null
echo "=== refreshed as-built copies ==="
for f in vermeer.dsc vermeer.fdf vermeer.toml MemoryMapLib.c ConfigurationMapLib.c BUILD_REPORT.TXT BUILDLOG_vermeerPkg.txt; do
  printf '  %-26s %s\n' "$f" "$(stat -c '%s bytes  %y' "$OUT/$f" 2>/dev/null | cut -d. -f1)"
done
echo
echo "=== fdf gating in the published copy ==="
grep -n 'VERMEER_VENDOR_HW\|#INF EmbeddedPkg/Drivers/DtPlatformDxe\|#  SECTION RAW' "$OUT/vermeer.fdf"
echo
echo "=== published firmware sha (must equal the one inside the .img) ==="
sha256sum "$OUT/SILICIUM_UEFI.fd" "$OUT/Mu-vermeer.img"
