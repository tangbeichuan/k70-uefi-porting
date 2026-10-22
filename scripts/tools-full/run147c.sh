set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys146/keys147c/g' build_keys146.sh > build_keys147c.sh
sed 's/keys146/keys147c/g' run_keys146.sh > run_keys147c.sh
chmod +x build_keys147c.sh run_keys147c.sh
# regenerate source copy hooks: patch_extn136 copies from port-drivers, no extra patch needed
grep -c 'patch_extn136' build_keys147c.sh
set +e
bash run_keys147c.sh 2>&1 | tail -18