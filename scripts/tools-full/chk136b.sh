set +e
python3 - <<'PY'
import pathlib
fv = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv')
d = fv.read_bytes()
pro = bytes.fromhex('b4513c7a629e1f4d8c0a2b5e6d7f1a93')
dt  = bytes.fromhex('3a1c5b7e249d774e9c1b2a6d5f8e4c31')
menu= bytes.fromhex('2e1c7a4fb593684da1e76c2b8f5d3a90')
print('FVMAIN', len(d), 'provider:', d.count(pro), 'dt:', d.count(dt), 'menu:', d.count(menu))
print('provider string:', d.find(b'vermeer dtb-extn provider'))
PY
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv | cat