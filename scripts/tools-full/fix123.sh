set +e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys123.sh
sed -i 's|python3 /mnt/d/本地项目-01/_tools/patch_logdisk122.py|python3 /mnt/d/本地项目-01/_tools/patch_copy123.py|' "$B"
sed -i 's|python3 /mnt/d/本地项目-01/_tools/patch_usbdev122.py|python3 /mnt/d/本地项目-01/_tools/patch_order123.py|' "$B"
grep -n 'patch_' "$B" | head -6