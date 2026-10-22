set +e
P=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "PKG source has USB149:"; grep -c 'USB149' "$P"
echo "port-drivers source has USB149:"; grep -c 'USB149' /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "=== patch_menu101 src/dst lines ==="
sed -n '1,20p' /mnt/d/本地项目-01/_tools/patch_menu101.py