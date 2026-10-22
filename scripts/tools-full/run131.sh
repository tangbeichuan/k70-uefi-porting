set +e
python3 /mnt/d/本地项目-01/_tools/widen131.py
grep -n 'SlotGetGeneric (0x' /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c | head
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed -e 's/keys130/keys131/g' run_keys130.sh > run_keys131.sh
sed -e 's/keys130/keys131/g' build_keys130.sh > build_keys131.sh
chmod +x run_keys131.sh build_keys131.sh
bash run_keys131.sh 2>&1 | tail -4