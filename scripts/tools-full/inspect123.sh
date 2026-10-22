set +e
echo "=== patch_copy123.py ==="
sed -n '1,60p' /mnt/d/本地项目-01/_tools/patch_copy123.py
echo "=== dsc provider? ==="
grep -n 'VermeerDtbExtnDxe\|VermeerLogDiskDxe\|VermeerMenuDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo "=== fdf provider? ==="
grep -n 'VermeerDtbExtnDxe\|7E5B1C3A' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf