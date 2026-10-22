sed -e 's/keys121/keys122/g' /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys121.sh > /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys122.sh
chmod +x /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys122.sh
python3 /mnt/d/本地项目-01/_tools/mk122.py
echo "=== drop lines in build_keys122.sh ==="
grep -n 'DROP = \[' -A6 /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys122.sh
echo "=== patch lines ==="
grep -n 'patch_' /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys122.sh