set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
# 删除后置声明
s=s.replace('\nSTATIC UINTN              mLastNode;\n','\n')
# 在 mBlobSize 声明后加
anchor='STATIC UINT32        mBlobSize;'
if 'STATIC UINTN        mLastNode;' not in s:
    s=s.replace(anchor, anchor+'\nSTATIC UINTN        mLastNode;', 1)
    print('moved to top')
io.open(p,'w',encoding='utf-8').write(s)
PY
grep -n "mLastNode;" "$F"
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys65 2>&1 | tail -4
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys65.fd" keys65 2>&1 | tail -3