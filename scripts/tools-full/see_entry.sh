set +e
D=/root/k70/uefi/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe
grep -n "ENTRY_POINT\|MODULE_TYPE\|Depex" "$D/SimpleFbDxe.inf"
echo "=== last 60 lines of SimpleFb.c ==="
tail -60 "$D/SimpleFb.c"