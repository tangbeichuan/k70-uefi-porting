#!/usr/bin/env bash
# Probe the *effective* package state of the keys140 patch chain WITHOUT building.
# Replaces the build_uefi.py step with greps, then exits (restore trap puts files back).
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg

cat > /tmp/probe_tail.sh <<'EOS'
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== PROBE: APRIORI.inc usb/stub lines ==="
grep -n -i -E "UsbConfigDxe|VermeerPmicVerStubDxe|UsbfnDwc3Dxe|UsbDeviceDxe|UsbInitDxe|UsbMsdDxe|UsbPwrCtrlDxe" "$PKG/Include/APRIORI.inc"
echo "=== PROBE: DXE.inc usbconfig lines ==="
grep -n -i "UsbConfigDxe" "$PKG/Include/DXE.inc"
echo "=== PROBE: vermeer.fdf usbconfig lines ==="
grep -n -i "UsbConfigDxe" "$PKG/vermeer.fdf"
echo "=== PROBE: dsc gate values ==="
grep -n -E "VERMEER_VENDOR_HW *=|VERMEER_VENDOR_INPUT *=|VERMEER_KEYPROBE *=" "$PKG/vermeer.dsc"
echo "=== PROBE: dsc components usb ==="
grep -n -i -E "UsbConfigDxe|VermeerPmicVerStubDxe|UsbInitDxe|UsbMsdDxe" "$PKG/vermeer.dsc"
echo "=== PROBE: APRIORI around line 170-220 ==="
sed -n '165,225p' "$PKG/Include/APRIORI.inc" | cat -n
exit 0
EOS

sed -e 's#^python3 build_uefi.py .*#bash /tmp/probe_tail.sh#' build_keys140.sh > build_keys140probe.sh
chmod +x build_keys140probe.sh
grep -n "probe_tail" build_keys140probe.sh
bash build_keys140probe.sh keys140probe 2>&1 | tail -80
