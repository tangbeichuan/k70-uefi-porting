set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
E=$(find "$B" -name "SimpleFbDxe.efi" | head -1)
echo "efi: $E"
ls -l "$E" 2>/dev/null
strings "$E" 2>/dev/null | grep -c "keys114"
strings "$E" 2>/dev/null | grep "FB\]" | head -3
echo "=== object freshness ==="
O=$(find "$B" -name "SimpleFb.obj" | head -1); ls -l "$O" 2>/dev/null
C=/root/k70/uefi/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFb.c
ls -l "$C"