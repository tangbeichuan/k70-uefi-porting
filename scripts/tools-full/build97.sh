set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 /mnt/d/本地项目-01/_tools/patch97.py
sed 's/keys96/keys97/g; s/bak96/bak97/g' run_keys96.sh > run_keys97.sh
bash run_keys97.sh 2>&1 | tail -14