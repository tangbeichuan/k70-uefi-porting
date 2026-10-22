#!/bin/bash
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== who includes APRIORI.inc ==="
grep -rn "APRIORI.inc" "$PKG" | head -20
echo
echo "=== Apriori GUID blocks in vermeer.fdf ==="
grep -n -A3 -B3 "FC1BCDB0" "$PKG/vermeer.fdf" | head -40
echo
echo "=== our driver in APRIORI.inc source? ==="
grep -n "VermeerDtDumpDxe\|VermeerKeyProbeDxe" "$PKG/Include/APRIORI.inc" || echo "  (not present now - build restores backups)"
echo
echo "=== tail of APRIORI.inc as it is now ==="
tail -6 "$PKG/Include/APRIORI.inc"
