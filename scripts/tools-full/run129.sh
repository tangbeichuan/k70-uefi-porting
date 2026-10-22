set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys128/keys129/g' run_keys128.sh > run_keys129.sh
sed -e 's/keys128/keys129/g' build_keys128.sh > build_keys129.sh
# ensure LogDisk insertion runs before the usb uncomment patch
sed -i 's|python3 /mnt/d/本地项目-01/_tools/patch_usb128.py|python3 /mnt/d/本地项目-01/_tools/patch_usb126.py \&\& python3 /mnt/d/本地项目-01/_tools/patch_usb128.py|' build_keys129.sh
grep -n 'patch_usb' build_keys129.sh
chmod +x run_keys129.sh build_keys129.sh
bash run_keys129.sh 2>&1 | tail -6