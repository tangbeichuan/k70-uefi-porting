set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys126/keys127/g' run_keys126.sh > run_keys127.sh
sed -e 's/keys126/keys127/g' build_keys126.sh > build_keys127.sh
sed -i 's|patch_usb126.py|patch_usb126.py \&\& python3 /mnt/d/本地项目-01/_tools/patch_pmicstub127.py|' build_keys127.sh
chmod +x run_keys127.sh build_keys127.sh
bash run_keys127.sh 2>&1 | tail -6