set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys85/keys86/g; s/bak85/bak86/g' run_keys85.sh > run_keys86.sh
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
grep -c '"UFS"' "$M" && echo "WARN: UFS region present, removing" && python3 - <<'PY'
import io
p='/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
s=s.replace('\n  {"UFS",                 0x01D80000, 0x00020000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},','')
io.open(p,'w',encoding='utf-8').write(s); print('removed')
PY
bash run_keys86.sh keys86 > /tmp/k86.log 2>&1; echo "run exit=$?"
grep -nE 'kept vendor|hard-dropped|error:|PROGRESS - Success' /tmp/k86.log | tail -5
grep -iE 'HALIOMMUDxe|UFSDxe|VermeerUfsMapDxe' /tmp/guid-keys86.xref 2>/dev/null || true
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys86.fd" keys86 2>&1 | tail -3