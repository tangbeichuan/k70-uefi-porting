set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys125/keys126/g' run_keys125.sh > run_keys126.sh
sed -e 's/keys125/keys126/g' build_keys125.sh > build_keys126.sh
sed -i 's|patch_usb125.py|patch_usb126.py|' build_keys126.sh
chmod +x run_keys126.sh build_keys126.sh
bash run_keys126.sh 2>&1 | tail -8