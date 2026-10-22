set +e
D=/root/k70/uefi/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFb.c
sed -n '85,130p' "$D"
echo "=== entry ==="
grep -n "SimpleFbDxeEntry\|InitializeSimpleFb\|^EFI_STATUS\|InstallMultipleProtocolInterfaces" "$D" | head -10
sed -n '195,260p' "$D"