set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 /mnt/d/本地项目-01/_tools/patch99.py
sed 's/keys98/keys99/g; s/bak98/bak99/g' run_keys98.sh > run_keys99.sh
bash run_keys99.sh 2>&1 | tail -8