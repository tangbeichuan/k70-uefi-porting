set +e
sed -e 's/keys122/keys123/g' /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys122.sh > /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys123.sh
sed -e 's/keys122/keys123/g' /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys122.sh > /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys123.sh
chmod +x /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys123.sh /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys123.sh
grep -n 'build_keys\|patch_' /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys123.sh /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys123.sh | head -12