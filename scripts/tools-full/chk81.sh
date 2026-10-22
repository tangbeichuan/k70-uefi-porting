set +e
cd /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe
python3 /mnt/d/本地项目-01/_tools/mk81.py
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak81
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D84000, 0x00003000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS region added')
PY
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys80/keys81/g; s/bak80/bak81/g' run_keys80.sh > run_keys81.sh
bash run_keys81.sh keys81 > /tmp/k81.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|error:|PROGRESS - Success' /tmp/k81.log | tail -4
cp /tmp/MemoryMapLib.c.bak81 "$M"
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys81.fd" keys81 2>&1 | tail -3