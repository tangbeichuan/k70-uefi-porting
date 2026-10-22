set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 - <<'PY'
import pathlib
s=pathlib.Path('run_keys73.sh').read_text(encoding='utf-8')
s=s.replace('keys73','keys77').replace('bak73','bak77')
old='    "usb", "xhci", "pildxe"'
assert old in s
# 只放行 host 侧：UsbConfig/UsbInit/UsbPwrCtrl/UsbMsd + 已有的 UsbBus/UsbMassStorage/UsbKb
s=s.replace(old,'    "usbfndwc3", "usbdevicedxe", "pildxe"',1)
pathlib.Path('run_keys77.sh').write_text(s,encoding='utf-8')
print('run_keys77.sh written')
PY
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
cp "$M" /tmp/MemoryMapLib.c.bak77
python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '"UFS"' not in s:
    old='  {"SMMU",                0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},'
    s=s.replace(old, old+'\n  {"UFS",                 0x01D84000, 0x00003000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},',1)
    io.open(p,'w',encoding='utf-8').write(s); print('UFS region added')
PY
bash run_keys77.sh keys77 > /tmp/k77.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|hard-dropped|error:|PROGRESS - Success' /tmp/k77.log | tail -6
cp /tmp/MemoryMapLib.c.bak77 "$M"
echo "--- 校验 FV 内 USB 组件 ---"
for g in UsbBusDxe UsbConfigDxe UsbInitDxe UsbPwrCtrlDxe UsbMassStorageDxe UsbfnDwc3Dxe; do printf "%-18s %s\n" "$g" "$(grep -c " $g\$" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref)"; done
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys77.fd" keys77 2>&1 | tail -3