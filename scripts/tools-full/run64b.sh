set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io,re
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
m=re.search(r'STATIC EFI_STATUS\nSlotGetByName \((?:.*\n)*?\}\n\n', s)
if m:
    s=s[:m.start()]+s[m.end():]
    print('SlotGetByName removed')
else:
    print('SlotGetByName not found')
io.open(p,'w',encoding='utf-8').write(s)
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys64 2>&1 | tail -4
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys64.fd" keys64 2>&1 | tail -3