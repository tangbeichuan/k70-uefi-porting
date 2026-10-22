set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
old='STATIC BOOLEAN            mInstalled;'
if 'STATIC UINTN              mLastNode;' not in s:
    s=s.replace(old, old+'\nSTATIC UINTN              mLastNode;', 1)
    print('decl added')
io.open(p,'w',encoding='utf-8').write(s)
PY
grep -n "STATIC UINTN              mLastNode" "$F"
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys65 2>&1 | tail -5
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys65.fd" keys65 2>&1 | tail -3