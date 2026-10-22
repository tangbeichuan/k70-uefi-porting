set +e
D=/root/k70/uefi/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe
echo "=== INF ==="
cat "$D/SimpleFbDxe.inf"
echo "=== depex section of file content (if any) ==="
sed -n '30,45p' "$D/SimpleFbDxe.inf"