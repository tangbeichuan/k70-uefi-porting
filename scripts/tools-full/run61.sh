set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
old="""    "[DTBEXTN] UNSUPPORTED slot called, LR=0x%lx\\n",
    (UINT64)(UINTN)Caller
    ));
  return EFI_NOT_FOUND;"""
new="""    "[DTBEXTN] UNSUPPORTED slot called (now returning SUCCESS), LR=0x%lx\\n",
    (UINT64)(UINTN)Caller
    ));
  return EFI_SUCCESS;"""
assert old in s, 'unsupported body not found'
s=s.replace(old,new,1)
io.open(p,'w',encoding='utf-8').write(s)
print('stub now returns SUCCESS')
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys61 2>&1 | tail -6
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys61.fd" keys61 2>&1 | tail -3