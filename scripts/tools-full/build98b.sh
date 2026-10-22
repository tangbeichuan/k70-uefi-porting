set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 /mnt/d/本地项目-01/_tools/patch98b.py
bash run_keys98.sh 2>&1 | tail -8