import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')
if 'UFS TEST HALT' not in s:
    old = '  Say (mHeader);\n\n  UfsDirectTest ();'
    new = ('  Say (mHeader);\n\n  UfsDirectTest ();\n\n'
           '  //\n  // keys88: 让屏上最后一段永远是我们自己的 UFS 结果，便于拍照判读\n  //\n'
           '  Say ("  === UFS TEST HALT (keys88) ===\\n");\n  CpuDeadLoop ();')
    assert old in s
    s = s.replace(old, new, 1)
    p.write_text(s, encoding='utf-8')
    print('patched probe: halt after UFS test')
else:
    print('already patched')

# APRIORI: 把 probe 挪到 Pcd.inf 之后（紧跟第 2 个派发），保证它在 EnvDxe 之前
ap = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc')
print('apriori check deferred to build script')