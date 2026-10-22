#!/bin/bash
D=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG
echo "=== map: head ==="
sed -n '1,25p' "$D/VermeerMenuDxe.map"
echo "=== map: entries with addresses 1B00-1E00 ==="
grep -nE '0*1[BCDE][0-9A-Fa-f]{2}' "$D/VermeerMenuDxe.map" | head -40
echo "=== full map symbol lines (address name) ==="
grep -E '^ *0*0{0,4}[0-9A-Fa-f]{4,5} ' "$D/VermeerMenuDxe.map" | head -120
