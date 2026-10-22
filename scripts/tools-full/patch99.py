import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

# 1) 声明开关
if 'mSkipMenu' not in s:
    s = s.replace('STATIC UINTN  mSkipUfsTest = 1;',
                  'STATIC UINTN  mSkipUfsTest = 1;   // 1=跳过裸 UFS 直控测试\nSTATIC UINTN  mSkipMenu    = 1;   // keys99: 1=不进入阻塞式菜单（让派发继续到 UFSDxe）', 1)

# 2) 在阻塞菜单循环之前插入提前返回
lines = s.split('\n')
target = None
for i, ln in enumerate(lines):
    if ln.strip() == 'for (;;) {' and i > 900:
        target = i
        break
assert target is not None, 'menu loop not found'
indent = ' ' * (len(lines[target]) - len(lines[target].lstrip()))
inject = [
    indent + 'if (mSkipMenu != 0) {',
    indent + '  Say ("  [UI] menu skipped (keys99) - dispatch continues\\n");',
    indent + '  return EFI_SUCCESS;',
    indent + '}',
    '',
]
lines[target:target] = inject
p.write_text('\n'.join(lines), encoding='utf-8')
print('patched keys99: menu gated, returns EFI_SUCCESS')