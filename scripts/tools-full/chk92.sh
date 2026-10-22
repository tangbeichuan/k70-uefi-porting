set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys91/keys92/g; s/bak91/bak92/g; s/ins_ufsmap91/widen_crypto92/g' run_keys91.sh > run_keys92.sh
bash run_keys92.sh keys92 > /tmp/k92.log 2>&1; echo "run exit=$?"
grep -nE "CRYPTO0 widened|ERROR|PROGRESS - Success" /tmp/k92.log | head -6
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys92.fd" keys92 2>&1 | tail -3