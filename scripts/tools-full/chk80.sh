set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 - <<'PY'
import pathlib
s=pathlib.Path('run_keys78.sh').read_text(encoding='utf-8')
s=s.replace('keys78','keys80').replace('bak78','bak80')
old='    "pmicdxe",   # keys67'
assert old in s, 'pmic token anchor not found'
s=s.replace(old,'    "keys80_keep_pmicdxe",   # keys80: PmicDxe 请回来（USB VBUS 需要 PMIC version 协议）',1)
pathlib.Path('run_keys80.sh').write_text(s,encoding='utf-8')
print('run_keys80.sh written')
PY
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak80
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D84000, 0x00003000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS region added')
PY
bash run_keys80.sh keys80 > /tmp/k80.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|error:|PROGRESS - Success' /tmp/k80.log | tail -5
cp /tmp/MemoryMapLib.c.bak80 "$M"
for g in PmicDxe UsbConfigDxe UsbBusDxe; do printf "%-16s %s\n" "$g" "$(grep -c " $g\$" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref)"; done
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys80.fd" keys80 2>&1 | tail -3