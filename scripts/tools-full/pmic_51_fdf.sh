#!/usr/bin/env bash
set +e
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== vermeer.fdf (all) ==="
cat -n "$PKG/vermeer.fdf"
echo
echo "=== dsc: Components section head + grep of Binaries lines ==="
grep -n -E "^\[|Binaries/vermeer|QcomPkg/Drivers" "$PKG/vermeer.dsc" | head -80
echo
echo "=== DXE.inc around usb lines ==="
sed -n '150,200p' "$PKG/Include/DXE.inc" | cat -n
echo
echo "=== APRIORI.inc around usb lines ==="
sed -n '140,215p' "$PKG/Include/APRIORI.inc" | cat -n
