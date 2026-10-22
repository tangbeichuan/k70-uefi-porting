set +e
SRC=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -c 'A3, 512)' "$SRC"
cp -f "$SRC" "$PKG"
touch "$PKG"
grep -c 'A3, 512)' "$PKG"
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys131/keys132/g' run_keys131.sh > run_keys132.sh
sed -e 's/keys131/keys132/g' build_keys131.sh > build_keys132.sh
chmod +x run_keys132.sh build_keys132.sh
bash run_keys132.sh 2>&1 | tail -4
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe/DEBUG/VermeerDtbExtnDxe.efi | cat