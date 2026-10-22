set +e
U=/root/k70/uefi
echo "=== existing working INF (DtbExtn) ==="; cat $U/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf
echo "=== candidate dec paths ==="
ls -1 $U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dec 2>/dev/null
ls -1 $U/Platforms/Xiaomi/vermeerPkg/vermeerPkg.dec 2>/dev/null
find $U/Platforms/Xiaomi -maxdepth 2 -name '*.dec' | head
echo "=== my INF ==="; nl -ba $U/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf | sed -n '10,25p'