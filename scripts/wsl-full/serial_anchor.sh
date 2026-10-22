set -u
cd /root/k70/uefi
echo "=== QEMU_BRINGUP block in vermeer.dsc ==="
grep -n "QEMU_BRINGUP" -A 12 Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo
echo "=== [LibraryClasses] tail (to find an anchor) ==="
grep -n "LibraryClasses\]\|^\[" Platforms/Xiaomi/vermeerPkg/vermeer.dsc | head -20
echo
echo "=== existing SerialPortLib/PcdSerial/PcdUart lines in dsc+inc ==="
grep -rn "PcdSerialRegisterBase\|PcdSerialBaudRate\|PL011UartClkInHz\|PcdUartDefault" \
  Platforms/Xiaomi/vermeerPkg/vermeer.dsc Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc Silicon/Qualcomm/KailuaPkg/KailuaPkg.dsc.inc 2>/dev/null
echo
echo "=== where is PcdSerialBaudRate / PL011UartClkInHz declared ==="
grep -rn "PcdSerialBaudRate\|PL011UartClkInHz" Mu_Basecore/ArmPlatformPkg/ArmPlatformPkg.dec Mu_Basecore/MdeModulePkg/MdeModulePkg.dec | head
