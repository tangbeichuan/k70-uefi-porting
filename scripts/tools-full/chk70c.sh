set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
grep -n "trap\|cp .*bak\|BACKUP" run_keys69.sh | head -20
echo "-----"
sed -n '1,40p' run_keys69.sh