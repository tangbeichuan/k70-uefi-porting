set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 - <<'PY'
import pathlib
s=pathlib.Path('run_keys73.sh').read_text(encoding='utf-8')
s=s.replace('keys73','keys76').replace('bak73','bak76')
old='    "usb", "xhci", "pildxe"'
assert old in s, 'drop pattern not found'
s=s.replace(old,'    "pildxe"',1)   # 保留 USB 全家（含 UsbBusDxe/UsbConfigDxe/UsbMassStorageDxe/UsbKbDxe）
pathlib.Path('run_keys76.sh').write_text(s,encoding='utf-8')
print('run_keys76.sh written')
PY
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak76
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D84000, 0x00003000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS region added')
PY
bash run_keys76.sh keys76 > /tmp/k76.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|hard-dropped|error:|PROGRESS - Success' /tmp/k76.log | tail -6
cp /tmp/MemoryMapLib.c.bak76 "$M"
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys76.fd" keys76 2>&1 | tail -3