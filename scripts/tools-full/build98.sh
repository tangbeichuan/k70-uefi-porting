set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 /mnt/d/本地项目-01/_tools/patch98.py
sed 's/keys97/keys98/g; s/bak97/bak98/g' run_keys97.sh > run_keys98.sh
bash run_keys98.sh 2>&1 | tail -10