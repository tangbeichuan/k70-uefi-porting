set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys135/keys136/g' run_keys135.sh > run_keys136.sh
sed -e 's/keys135/keys136/g' build_keys135.sh > build_keys136.sh
sed -i 's|patch_copy123.py|patch_copy123.py \&\& python3 /mnt/d/本地项目-01/_tools/patch_extn136.py|' build_keys136.sh
grep -n 'patch_extn136' build_keys136.sh
chmod +x run_keys136.sh build_keys136.sh
bash run_keys136.sh > /tmp/b136.log 2>&1
tail -4 /tmp/b136.log