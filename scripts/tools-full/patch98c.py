import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

s = s.replace('  if (mLegacyProbe == 3) { UfsDirectTest (); }   // keys98: 跳过裸 UFS 测试',
              '  if (mSkipUfsTest == 0) { UfsDirectTest (); }   // keys98: 跳过裸 UFS 测试', 1)

# 在 mHeader 定义之前插一个开关
anchor = 'STATIC CONST CHAR8  mHeader[] ='
assert anchor in s
if 'mSkipUfsTest' not in s.split(anchor)[0]:
    s = s.replace(anchor, 'STATIC UINTN  mSkipUfsTest = 1;   // keys98: 1=跳过裸 UFS 直控测试\n\n' + anchor, 1)
p.write_text(s, encoding='utf-8')
print('declared mSkipUfsTest and gated the call')