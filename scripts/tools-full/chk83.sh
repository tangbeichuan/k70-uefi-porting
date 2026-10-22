set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys82/keys83/g; s/bak82/bak83/g' run_keys82.sh > run_keys83.sh
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak83
grep -n '"UFS"' "$M" || echo "no UFS region (clean tree)"
bash run_keys83.sh keys83 > /tmp/k83.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|error:|PROGRESS - Success' /tmp/k83.log | tail -4
cp /tmp/MemoryMapLib.c.bak83 "$M"
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys83.fd" keys83 2>&1 | tail -3