set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys93/keys94/g; s/bak93/bak94/g; s/ins_map93/ins_map93/g' run_keys93.sh > run_keys94.sh
bash run_keys94.sh keys94 > /tmp/k94.log 2>&1; echo "run exit=$?"
grep -nE "error:|ERROR|PROGRESS - Success|memmap entries" /tmp/k94.log | head -6
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys94.fd" keys94 2>&1 | tail -3