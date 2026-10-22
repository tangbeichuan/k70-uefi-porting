set -u
cd /root/k70/uefi
echo "=== PcdPlatformBootTimeOut declaration ==="
grep -rn "PcdPlatformBootTimeOut" Mu_Basecore/MdeModulePkg/MdeModulePkg.dec
echo
echo "=== who consumes it ==="
grep -rn "PcdPlatformBootTimeOut" Mu_Basecore/MdeModulePkg/Universal/BdsDxe/*.c Mu_Basecore/MdeModulePkg/Universal/BdsDxe/*.h 2>/dev/null | head
grep -rn "PcdPlatformBootTimeOut" Mu_Basecore/MdeModulePkg/Library/UefiBootManagerLib/*.c 2>/dev/null | head
echo
echo "=== current PcdsFixedAtBuild section of vermeer.dsc ==="
sed -n '/^\[PcdsFixedAtBuild\]/,/^\[/p' Platforms/Xiaomi/vermeerPkg/vermeer.dsc | head -40
