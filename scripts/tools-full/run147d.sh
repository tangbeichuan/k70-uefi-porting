set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys146/keys147d/g' build_keys146.sh > build_keys147d.sh
sed 's/keys146/keys147d/g' run_keys146.sh > run_keys147d.sh
chmod +x build_keys147d.sh run_keys147d.sh
set +e
bash run_keys147d.sh 2>&1 | tail -14