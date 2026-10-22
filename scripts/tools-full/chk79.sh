set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys78/keys79/g; s/bak78/bak79/g' run_keys78.sh > run_keys79.sh
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak79
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D84000, 0x00003000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS region added')
PY
bash run_keys79.sh keys79 > /tmp/k79.log 2>&1; echo "run exit=$?"
grep -nE 'error:|Error:|PROGRESS - Success' /tmp/k79.log | tail -6
cp /tmp/MemoryMapLib.c.bak79 "$M"
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys79.fd" keys79 2>&1 | tail -3