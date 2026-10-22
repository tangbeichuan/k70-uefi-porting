set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys94/keys95/g; s/bak94/bak95/g' run_keys94.sh > run_keys95.sh
grep -n "keys95\|TAG\|build_keys" run_keys95.sh | head -20