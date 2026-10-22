set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 - <<'PY'
import pathlib
s=pathlib.Path('run_keys77.sh').read_text(encoding='utf-8')
s=s.replace('keys77','keys78').replace('bak77','bak78')
old='''    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        low = line.lower()
        if low.lstrip().startswith("inf") and "binaries/vermeer" in low:'''
new='''    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        # 先还原上一轮我们自己加的注释，保证本轮 DROP 列表真的生效
        if line.startswith("# [keys47-drop] "):
            line = line[len("# [keys47-drop] "):]
        elif line.startswith("# [keys70-hard] "):
            line = line[len("# [keys70-hard] "):]
        low = line.lower()
        if low.lstrip().startswith("inf") and "binaries/vermeer" in low:'''
assert old in s, 'loop pattern not found'
s=s.replace(old,new,1)
pathlib.Path('run_keys78.sh').write_text(s,encoding='utf-8')
print('run_keys78.sh written')
PY
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak78
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D84000, 0x00003000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS region added')
PY
bash run_keys78.sh keys78 > /tmp/k78.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|hard-dropped|error:|PROGRESS - Success' /tmp/k78.log | tail -6
cp /tmp/MemoryMapLib.c.bak78 "$M"
echo "--- FV 内 USB 组件 ---"
for g in UsbBusDxe UsbConfigDxe UsbInitDxe UsbPwrCtrlDxe UsbMassStorageDxe UsbfnDwc3Dxe UsbDeviceDxe; do printf "%-18s %s\n" "$g" "$(grep -c " $g\$" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref)"; done
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys78.fd" keys78 2>&1 | tail -3