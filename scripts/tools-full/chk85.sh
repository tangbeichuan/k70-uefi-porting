set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys84/keys85/g; s/bak84/bak85/g' run_keys84.sh > run_keys85.sh
# 去掉 HALIOMMU 的 hard-drop 步骤：把该 python 块的中性化（改为不删除）
python3 - <<'PY'
import pathlib
p=pathlib.Path('run_keys85.sh'); s=p.read_text(encoding='utf-8')
if '# [keys70-hard] ' in s:
    s=s.replace('out.append("# [keys70-hard] " + line); n += 1','out.append(line)  # keys85: keep HALIOMMU',1)
    p.write_text(s,encoding='utf-8'); print('HALIOMMU kept for keys85')
else:
    print('anchor not found')
PY
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak85
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D80000, 0x00020000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS region added (PEI map) - may hang, test')
PY
bash run_keys85.sh keys85 > /tmp/k85.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|hard-dropped|error:|PROGRESS - Success' /tmp/k85.log | tail -5
cp /tmp/MemoryMapLib.c.bak85 "$M"
grep -iE 'HALIOMMUDxe|UFSDxe|VermeerUfsMapDxe' /tmp/guid-keys85.xref 2>/dev/null || true
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys85.fd" keys85 2>&1 | tail -3