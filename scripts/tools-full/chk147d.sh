#!/usr/bin/env bash
set -u
cd /root/k70/uefi
B=Build/vermeerPkg/DEBUG_CLANGPDB
echo "=== DtbExtn efi candidates ==="
find "$B" -name 'VermeerDtbExtnDxe.efi' | while read -r f; do
  echo "--- $f  $(stat -c%s "$f")B"
  grep -ac 'VBUS' "$f" || true
done
echo "=== fdf/dxe vbus lines ==="
grep -n 'Vbus\|VBUS' Platforms/Xiaomi/vermeerPkg/vermeer.fdf Platforms/Xiaomi/vermeerPkg/Include/DXE.inc Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc 2>/dev/null | head
echo "=== Vbus GUID inside FVMAIN.Fv ==="
grep -aco '4A8E2C71' "$B/FV/FVMAIN.Fv" || true
echo "=== FVMAIN.inf vbus ==="
grep -n -i 'vbus' "$B/FV/FVMAIN.inf" 2>/dev/null | head
echo "=== logdisk efi candidates (diag?) ==="
find "$B" -name 'VermeerLogDiskDxe.efi' | while read -r f; do
  echo "--- $f $(stat -c%s "$f")B USBDIAG=$(grep -ac 'USBDIAG' "$f" || true)"
done
echo "=== build src of logdisk (patch_copy123 source) ==="
grep -c 'USBDIAG' /mnt/d/本地项目-01/_tools/VermeerLogDiskDxe.c || true
echo "=== FD built sha ==="
sha256sum "$B/FV/SILICIUM_UEFI.fd" 2>/dev/null || true
ls -l --time-style=+%H:%M:%S "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" 2>/dev/null
