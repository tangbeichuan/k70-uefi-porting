import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
lines = p.read_text(encoding='utf-8').split('\n')
# 行号是 1-based：914 Say(mHeader); 916 UfsDirectTest();
idx = None
for i, ln in enumerate(lines):
    if 'UfsDirectTest ();' in ln and i > 800:
        idx = i
        break
assert idx is not None, 'call not found'
print('call at line', idx+1, repr(lines[idx]))
lines[idx] = '  if (mLegacyProbe == 3) { UfsDirectTest (); }   // keys98: 跳过裸 UFS 测试'
p.write_text('\n'.join(lines), encoding='utf-8')
print('patched keys98')