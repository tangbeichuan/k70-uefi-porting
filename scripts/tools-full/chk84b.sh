set +e
cd /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerUfsMapDxe
python3 - <<'PY'
import pathlib
c=pathlib.Path('VermeerUfsMapDxe.c'); s=c.read_text(encoding='utf-8')
if 'DxeServicesTableLib.h' not in s:
    s=s.replace('#include <Library/UefiBootServicesTableLib.h>',
                '#include <Library/UefiBootServicesTableLib.h>\n#include <Library/DxeServicesTableLib.h>',1)
    c.write_text(s,encoding='utf-8'); print('c: include added')
inf=pathlib.Path('VermeerUfsMapDxe.inf'); t=inf.read_text(encoding='utf-8')
if 'DxeServicesTableLib' not in t:
    t=t.replace('  DebugLib','  DebugLib\n  DxeServicesTableLib',1)
    inf.write_text(t,encoding='utf-8'); print('inf: lib added')
PY
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash run_keys84.sh keys84 > /tmp/k84b.log 2>&1; echo "run exit=$?"
grep -nE 'error:|ERROR|PROGRESS - Success' /tmp/k84b.log | head -6
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys84.fd" keys84 2>&1 | tail -3