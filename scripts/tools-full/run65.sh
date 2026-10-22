set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()

# 1) 全局变量
if 'mLastNode' not in s:
    anchor='STATIC BOOLEAN  mInstalled'
    idx = s.find(anchor)
    if idx == -1:
        # 退回：找 mInstalled 定义行
        idx = s.find('mInstalled')
    s = s.replace('mInstalled = FALSE;', 'mInstalled = FALSE;\nSTATIC UINTN  mLastNode = 0;\n', 1) if 'mInstalled = FALSE;' in s else s
    print('global inserted?', 'mLastNode' in s)

# 2) GetNode 里记录
s = s.replace('  *Node = (VOID *)(UINTN)(mBlob + Off);',
              '  *Node = (VOID *)(UINTN)(mBlob + Off);\n  mLastNode = (UINTN)*Node;', 1)

# 3) 通用取属性里，若无 blob 指针则退回 mLastNode
old = '''  if ((Node == 0) || (Name == 0) || (Out == 0)) {'''
new = '''  if ((Node == 0) && (mLastNode != 0)) {
    Node = mLastNode;
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> using last node 0x%lx\\n", Tag, (UINT64)Node));
  }

  if ((Node == 0) || (Name == 0) || (Out == 0)) {'''
assert old in s
s = s.replace(old, new, 1)
io.open(p,'w',encoding='utf-8').write(s)
print('last-node fallback added')
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys65 2>&1 | tail -4
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys65.fd" keys65 2>&1 | tail -3