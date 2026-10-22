set +e
D=/root/k70/uefi/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe
ls "$D"
echo "=== SimpleFb.c key lines ==="
grep -n "DEBUG\|InstallMultipleProtocolInterfaces\|FrameBuffer\|Pcd\|GetVariable\|LocateHandle\|GraphicalPolicy\|Allocate" "$D/SimpleFb.c" | head -40