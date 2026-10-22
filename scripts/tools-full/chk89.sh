set +e
cd /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe
python3 - <<'PY'
import pathlib
inf=pathlib.Path('VermeerKeyProbeDxe.inf'); t=inf.read_text(encoding='utf-8')
if 'DxeServicesTableLib' not in t:
    t=t.replace('  UefiLib','  UefiLib\n  DxeServicesTableLib',1)
    inf.write_text(t,encoding='utf-8'); print('inf: DxeServicesTableLib added')

c=pathlib.Path('VermeerKeyProbeDxe.c'); s=c.read_text(encoding='utf-8')
if 'DxeServicesTableLib.h' not in s:
    s=s.replace('#include <Library/CacheMaintenanceLib.h>',
                '#include <Library/CacheMaintenanceLib.h>\n#include <Library/DxeServicesTableLib.h>',1)
    c.write_text(s,encoding='utf-8'); print('c: include added')

# 在 UfsDirectTest 开头自己把 UFS MMIO 映射加进 GCD（不再依赖 VermeerUfsMapDxe 的先后顺序）
marker = '  UfsPrint ("[UFS71] ==== direct UFS probe (no IOMMU, no DT) ====\\n");'
if 'keys89 map' not in s:
    ins = marker + '''

  //
  // keys89: 不管本驱动排在哪，自己先把 UFS MMIO 窗口加进 GCD 并设为 UC
  //
  if (gDS != NULL) {
    EFI_STATUS  MapSt;
    MapSt = gDS->AddMemorySpace (EfiGcdMemoryTypeMemoryMappedIo, 0x01D80000ULL, 0x00020000ULL,
                                 EFI_MEMORY_UC | EFI_MEMORY_RUNTIME);
    AsciiSPrint (Line, sizeof (Line), "[UFS89] AddMemorySpace -> %r\\n", MapSt);
    UfsPrint (Line);
    MapSt = gDS->SetMemorySpaceAttributes (0x01D80000ULL, 0x00020000ULL, EFI_MEMORY_UC);
    AsciiSPrint (Line, sizeof (Line), "[UFS89] SetMemorySpaceAttributes -> %r\\n", MapSt);
    UfsPrint (Line);
  }'''
    assert marker in s
    s=s.replace(marker, ins, 1)
    c.write_text(s,encoding='utf-8'); print('c: keys89 map inserted')
PY
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys88/keys89/g; s/bak88/bak89/g' run_keys88.sh > run_keys89.sh 2>/dev/null || sed 's/keys84/keys89/g; s/bak84/bak89/g' run_keys84.sh > run_keys89.sh
python3 - <<'PY'
import pathlib
p=pathlib.Path('run_keys89.sh'); s=p.read_text(encoding='utf-8')
if 'move_probe88.py' not in s:
    anchor='python3 /mnt/d/本地项目-01/_tools/patch_ufsmap84.py "$PKG"'
    if anchor in s:
        s=s.replace(anchor, anchor + '\npython3 /mnt/d/本地项目-01/_tools/move_probe88.py "$PKG/Include/APRIORI.inc"',1)
p.write_text(s,encoding='utf-8'); print('run_keys89 ready')
PY
bash run_keys89.sh keys89 > /tmp/k89.log 2>&1; echo "run exit=$?"
grep -nE "apriori: probe inserted|ERROR|PROGRESS - Success" /tmp/k89.log | head -5
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys89.fd" keys89 2>&1 | tail -3