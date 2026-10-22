set +e
rm -rf /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys134/keys135/g' run_keys134.sh > run_keys135.sh
sed -e 's/keys134/keys135/g' build_keys134.sh > build_keys135.sh
chmod +x run_keys135.sh build_keys135.sh
bash run_keys135.sh > /tmp/b135.log 2>&1
tail -4 /tmp/b135.log
ls -l --time-style=+%H:%M:%S /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys135.fd | cat