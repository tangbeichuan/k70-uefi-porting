import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

old = '''  Say (mHeader);
  UfsDirectTest ();'''
new = '''  Say (mHeader);

  //
  // keys98: 自研裸 UFS 测试会出现"写 UTRLDBR 后整机停住"，
  // 先彻底跳过它（保留函数体以免 -Wunused-function），让派发继续到原厂 UFSDxe，
  // 由 UFSDxe + SMMU 桩自己初始化 UFS。
  //
  if (mLegacyProbe == 3) {
    UfsDirectTest ();
  }'''
assert old in s, 'header call site not found'
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('patched keys98: skip raw UFS test')