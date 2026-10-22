set +e
cd /mnt/d/本地项目-01/_k70port_extract/qemu-fw
sha256sum SILICIUM_UEFI-keys68.fd SILICIUM_UEFI-keys69.fd
cmp -l SILICIUM_UEFI-keys68.fd SILICIUM_UEFI-keys69.fd | head -5
cmp -l SILICIUM_UEFI-keys68.fd SILICIUM_UEFI-keys69.fd | wc -l
echo "=== run_keys69.sh 里的 pack 调用 ==="
grep -n "pack_keys.sh" /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys69.sh