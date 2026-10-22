set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys133.fd keys133 2>&1 | tail -5
ls -l /mnt/d/本地项目-01/K70-UEFI-build/*keys133* 2>/dev/null | cat