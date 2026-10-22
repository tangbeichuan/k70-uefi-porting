set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys127/keys128/g' run_keys127.sh > run_keys128.sh
sed -e 's/keys127/keys128/g' build_keys127.sh > build_keys128.sh
sed -i 's|patch_usb126.py|patch_usb128.py|' build_keys128.sh
chmod +x run_keys128.sh build_keys128.sh
bash run_keys128.sh 2>&1 | tail -6