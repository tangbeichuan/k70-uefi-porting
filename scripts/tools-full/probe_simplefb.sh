set +e
U=/root/k70/uefi
ls -l $U/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/ 2>/dev/null
echo "--- INF ---"
cat $U/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf 2>/dev/null
echo "--- grep Pcd in SimpleFb.c ---"
grep -n "Pcd\|FrameBuffer\|gBS->Allocate\|Gop\|Mode" $U/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFb.c 2>/dev/null | head -40