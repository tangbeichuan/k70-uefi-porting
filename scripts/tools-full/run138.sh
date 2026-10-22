set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys137/keys138/g' run_keys137.sh > run_keys138.sh
sed -e 's/keys137/keys138/g' build_keys137.sh > build_keys138.sh
sed -i 's|patch_pmicstub127.py|patch_pmicstub127.py \&\& python3 /mnt/d/本地项目-01/_tools/patch_nopmic138.py|' build_keys138.sh
grep -n 'patch_nopmic138' build_keys138.sh
chmod +x run_keys138.sh build_keys138.sh
bash run_keys138.sh > /tmp/b138.log 2>&1
tail -12 /tmp/b138.log