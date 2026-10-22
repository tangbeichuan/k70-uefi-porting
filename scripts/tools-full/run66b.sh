set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
old="""  EFI_STATUS  Status;
  UINTN       i;

  Quiet = SeenBefore (SlotId, A1);"""
new="""  EFI_STATUS  Status;
  UINTN       i;
  BOOLEAN     Quiet;

  Quiet = SeenBefore (SlotId, A1);"""
assert old in s
s=s.replace(old,new,1)
io.open(p,'w',encoding='utf-8').write(s)
print('Quiet declared')
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys66 2>&1 | tail -4
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys66.fd" keys66 2>&1 | tail -3