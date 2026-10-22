set -u
cd /root/k70/uefi
echo "=== PL011 / serial libraries in the tree ==="
find . -iname '*PL011*' -o -iname '*SerialPortLib*.inf' | grep -i -E 'pl011|serialportlib' | head -20
echo
echo "=== ArmPlatformPkg present? ==="
ls -d ArmPlatformPkg ArmPkg 2>/dev/null
echo
echo "=== what SerialPortLib does the platform use? ==="
grep -n "SerialPortLib" Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc | head
echo
echo "=== platform dsc serial overrides ==="
grep -n "SerialPort" Platforms/Xiaomi/vermeerPkg/vermeer.dsc
