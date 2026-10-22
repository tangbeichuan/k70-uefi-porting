#!/bin/bash
MAP=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG/VermeerMenuDxe.map
echo "=== obj sections & symbols in 0x1A00-0x1E00 range ==="
awk '$1 ~ /^[0-9A-Fa-f]{8}$/ { a=strtonum("0x"$1); if (a>=0x1A00 && a<=0x1E00) print }' "$MAP" 2>/dev/null || true
echo "=== VermeerMenuDxe obj lines ==="
grep -n "VermeerMenuDxe" "$MAP" | head -30
echo "=== symbols whose line has .obj and address 1C.. (grep) ==="
grep -nE '^00001[BC][0-9A-F]{2} ' "$MAP" | head -40
echo "=== tail of map ==="
tail -60 "$MAP"
