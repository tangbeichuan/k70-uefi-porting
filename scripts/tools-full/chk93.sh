set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys91/keys93/g; s/bak91/bak93/g; s/ins_ufsmap91/ins_map93/g' run_keys91.sh > run_keys93.sh
bash run_keys93.sh keys93 > /tmp/k93.log 2>&1; echo "run exit=$?"
grep -nE "memmap entries added|ERROR|PROGRESS - Success" /tmp/k93.log | head -6
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys93.fd" keys93 2>&1 | tail -3