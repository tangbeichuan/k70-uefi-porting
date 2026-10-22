set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()
old='STATIC BOOLEAN            mInstalled;'
if 'mLastNode' not in s.split('mInstalled;')[0]:
    if old in s:
        s=s.replace(old, 'STATIC BOOLEAN            mInstalled;\nSTATIC UINTN              mLastNode;', 1)
        print('global added')
    else:
        print('anchor missing')
# 文件末尾的孤行 mLastNode = 0; 去掉
s=s.replace('\nSTATIC UINTN  mLastNode = 0;\n','\n')
io.open(p,'w',encoding='utf-8').write(s)
print('mLastNode' in s)
PY
grep -n "mLastNode" "$F" | head
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys65 2>&1 | tail -4
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys65.fd" keys65 2>&1 | tail -3