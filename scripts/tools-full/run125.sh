set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys124/keys125/g' run_keys124.sh > run_keys125.sh
sed -e 's/keys124/keys125/g' build_keys124.sh > build_keys125.sh
sed -i 's|python3 /mnt/d/本地项目-01/_tools/patch_order123.py|python3 /mnt/d/本地项目-01/_tools/patch_usb125.py|' build_keys125.sh
chmod +x run_keys125.sh build_keys125.sh
grep -n 'patch_' build_keys125.sh | head
bash run_keys125.sh 2>&1 | tail -8