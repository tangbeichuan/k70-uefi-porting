set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys133/keys134/g' run_keys133.sh > run_keys134.sh
sed -e 's/keys133/keys134/g' build_keys133.sh > build_keys134.sh
chmod +x run_keys134.sh build_keys134.sh
bash run_keys134.sh > /tmp/b134.log 2>&1
tail -4 /tmp/b134.log
ls -l --time-style=+%H:%M:%S /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerDtbExtnDxe.efi | cat