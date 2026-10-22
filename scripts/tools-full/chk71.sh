set +e
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak71
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' in s:
    print('UFS entry already there')
else:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    new=old+'\n  {"UFS",                 0x01D84000, 0x00003000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    assert old in s, 'SMMU line not found'
    s=s.replace(old,new,1)
    io.open(p,'w',encoding='utf-8').write(s)
    print('UFS region added')
PY
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash run_keys71.sh keys71 > /tmp/k71.log 2>&1; echo "run exit=$?"
grep -nE 'hard-dropped|kept vendor|UFSDxe kept|Success|error:' /tmp/k71.log | tail -6
for g in 9A00771F 0D35CD8E 5C1E9A73 5B21E7C4; do printf "%s : " $g; grep -c "$g" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt; done
cp /tmp/MemoryMapLib.c.bak71 "$M"
grep -c '"UFS"' "$M"
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys71.fd 2>/dev/null