set -u
cd /root/k70/uefi
echo "=== PL011SerialPortLib.inf ==="
cat Mu_Basecore/ArmPlatformPkg/Library/PL011SerialPortLib/PL011SerialPortLib.inf
echo
echo "=== PCDs used by PL011SerialPortLib.c / PL011UartLib ==="
grep -n "Pcd\|FixedPcd" Mu_Basecore/ArmPlatformPkg/Library/PL011SerialPortLib/PL011SerialPortLib.c | head -20
echo "---"
grep -n "Pcd\|FixedPcd" Mu_Basecore/ArmPlatformPkg/Library/PL011UartLib/PL011UartLib.c | head -20
echo
echo "=== PL011UartClockLib ==="
cat Mu_Basecore/ArmPlatformPkg/Library/PL011UartClockLib/PL011UartClockLib.c | head -40
echo
echo "=== is ArmPlatformPkg in PACKAGES_PATH? ==="
grep -rn "Mu_Basecore" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/DeviceBuild.py | head -5
