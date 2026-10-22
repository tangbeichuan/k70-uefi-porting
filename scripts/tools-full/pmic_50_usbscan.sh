#!/usr/bin/env bash
set +e
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
BIN=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
echo "=== APRIORI.inc: usb-ish lines (with line numbers) ==="
grep -n -i -E "usb|PmicVerStub" "$PKG/Include/APRIORI.inc"
echo
echo "=== DXE.inc: usb-ish lines ==="
grep -n -i -E "usb|PmicVerStub" "$PKG/Include/DXE.inc"
echo
echo "=== RAW.inc: usb-ish lines ==="
grep -n -i -E "usb|PmicVerStub" "$PKG/Include/RAW.inc" 2>/dev/null
echo
echo "=== vermeer.dsc: usb-ish lines ==="
grep -n -i "usb" "$PKG/vermeer.dsc"
echo
echo "=== vermeer.fdf: usb-ish lines ==="
grep -n -i "usb" "$PKG/vermeer.fdf"
echo
echo "=== UsbConfigDxe dir ==="
ls -l "$BIN/UsbConfigDxe" 2>/dev/null
echo "=== UsbConfigDxe.inf ==="
cat "$BIN/UsbConfigDxe/UsbConfigDxe.inf" 2>/dev/null
echo "=== UsbConfigDxe depex (binary) ==="
ls -l "$BIN/UsbConfigDxe"/*.depex 2>/dev/null
