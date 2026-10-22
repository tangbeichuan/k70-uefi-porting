set +e
SRC=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
cp -f "$SRC" "$PKG"; touch "$PKG"
echo "PKG 512 count: $(grep -c 'A3, 512)' $PKG)"
rm -rf /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerDtbExtnDxe
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys132/keys133/g' run_keys132.sh > run_keys133.sh
sed -e 's/keys132/keys133/g' build_keys132.sh > build_keys133.sh
chmod +x run_keys133.sh build_keys133.sh
bash run_keys133.sh > /tmp/b133.log 2>&1
echo "--- build errors (if any) ---"
grep -iE 'error:|Error [0-9]{4}|undefined symbol' /tmp/b133.log | grep -v 'error.h' | head -10
tail -4 /tmp/b133.log
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe/DEBUG/VermeerDtbExtnDxe.efi 2>/dev/null | cat