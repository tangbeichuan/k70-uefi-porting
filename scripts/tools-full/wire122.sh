set +e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys122.sh
grep -q 'patch_usbdev122' "$B" || sed -i 's|^source /root/k70/venv/bin/activate$|python3 /mnt/d/本地项目-01/_tools/patch_usbdev122.py\nsource /root/k70/venv/bin/activate|' "$B"
grep -n 'patch_usbdev122\|source /root/k70/venv' "$B"