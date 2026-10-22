set +e
G=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref
echo "SimpleFbDxe:"; grep -i "DCFD1E6D" $G | head -3
echo "MenuDxe:"; grep -i "4F7A1C2E" $G | head -3
echo "APRIORI SimpleFb:"; grep -n "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "dsc SimpleFb:"; grep -n "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe/OUTPUT/SimpleFb.efi 2>/dev/null