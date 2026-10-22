set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys84/keys87/g; s/bak84/bak87/g' run_keys84.sh > run_keys87.sh
bash run_keys87.sh keys87 > /tmp/k87.log 2>&1; echo "run exit=$?"
grep -nE 'error:|ERROR|PROGRESS - Success|ufsmap patch|kept vendor' /tmp/k87.log | head -8
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys87.fd" keys87 2>&1 | tail -4