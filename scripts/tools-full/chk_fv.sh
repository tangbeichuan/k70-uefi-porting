set +e
echo "=== vermeer DXE.inc SimpleFb ==="
grep -n "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/DXE.inc
echo "=== SiliciumPkg/Common.fdf.inc ==="
grep -n "SimpleFbDxe" /root/k70/uefi/Silicon/Silicium/SiliciumPkg/Common.fdf.inc
echo "=== vermeer.dsc components SimpleFb ==="
grep -n "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo "=== who else includes SimpleFbDxe in FV (search built fdf after gates) ==="
cd /root/k70/uefi/Platforms/Xiaomi/vermeerPkg
cp vermeer.dsc /tmp/t2.dsc; cp vermeer.fdf /tmp/t2.fdf
python3 /mnt/d/本地项目-01/_k70port_extract/wsl/gates.py keyprobe vermeer.dsc vermeer.fdf >/dev/null 2>&1
awk 'NR>=40 && NR<=100' vermeer.fdf | grep -n "FV\.\|INF \|!include" | head -25
cp /tmp/t2.dsc vermeer.dsc; cp /tmp/t2.fdf vermeer.fdf