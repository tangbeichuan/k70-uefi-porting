set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
ls run_keys67.sh >/dev/null 2>&1 && echo "have run_keys67"
sed 's/keys67/keys82/g; s/bak67/bak82/g' run_keys67.sh > run_keys82.sh
python3 - <<'PY'
import pathlib
p=pathlib.Path('run_keys82.sh'); s=p.read_text(encoding='utf-8')
print('has ufsdxe keep line:', [l for l in s.splitlines() if 'ufsdxe' in l.lower()][:3])
print('has pmicdxe drop:', [l for l in s.splitlines() if 'pmicdxe' in l.lower()][:3])
PY
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak82
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D80000, 0x00020000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS 0x1D80000+0x20000 added')
PY
bash run_keys82.sh keys82 > /tmp/k82.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|error:|PROGRESS - Success' /tmp/k82.log | tail -4
cp /tmp/MemoryMapLib.c.bak82 "$M"
for g in UFSDxe PmicDxe HALIOMMUDxe; do printf "%-14s %s\n" "$g" "$(grep -c " $g\$" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref)"; done
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys82.fd" keys82 2>&1 | tail -3