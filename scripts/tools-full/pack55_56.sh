set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
for t in keys55 keys56; do
  echo "--- $t"
  bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$t.fd" "$t" 2>&1 | tail -4
done