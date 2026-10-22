set +e
cd /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe
# 打开 dump-only 宏
python3 - <<'PY'
import io
p='VermeerKeyProbeDxe.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '#define UFS74_DUMPONLY' not in s:
    s=s.replace('#include <Library/CacheMaintenanceLib.h>','#include <Library/CacheMaintenanceLib.h>\n#define UFS74_DUMPONLY 1',1)
    io.open(p,'w',encoding='utf-8').write(s); print('macro on')
else:
    print('macro already on')
PY
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak74
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
bash run_keys73.sh keys74 > /tmp/k74.log 2>&1; echo "run exit=$?"
grep -nE 'hard-dropped|kept vendor|Success|error:' /tmp/k74.log | tail -4
cp /tmp/MemoryMapLib.c.bak74 "$M"
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys74.fd" keys74 2>&1 | tail -3