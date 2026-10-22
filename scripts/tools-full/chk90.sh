set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys89/keys90/g; s/bak89/bak90/g' run_keys89.sh > run_keys90.sh
bash run_keys90.sh keys90 > /tmp/k90.log 2>&1; echo "run exit=$?"
grep -nE "apriori: probe inserted|error:|ERROR|PROGRESS - Success" /tmp/k90.log | head -6
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys90.fd" keys90 2>&1 | tail -3