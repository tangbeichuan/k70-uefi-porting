set +e
python3 /mnt/d/本地项目-01/_tools/patch_logdisk122.py; echo "patch rc=$?"
echo "=== dsc ==="; grep -n 'VermeerLogDiskDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo "=== apriori ==="; grep -n 'VermeerLogDiskDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== fdf ==="; grep -n 'VermeerLogDiskDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
echo "=== source dir ==="; ls -l /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerLogDiskDxe/ 2>/dev/null