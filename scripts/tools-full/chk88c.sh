set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash run_keys88.sh keys88 > /tmp/k88b.log 2>&1; echo "run exit=$?"
grep -nE "apriori: probe inserted|ERROR|PROGRESS - Success" /tmp/k88b.log | head -5
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys88.fd" keys88 2>&1 | tail -3