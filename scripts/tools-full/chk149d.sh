set +e
python3 - <<'PY'
import pathlib
fv = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv').read_bytes()
for s in ('[USB149] pre', '[USB149] run', '[USB149] post', '[MENU149]'):
    a = s.encode('ascii'); u = s.encode('utf-16-le')
    print(f"{s:16s} ascii={fv.find(a):>9d}  utf16={fv.find(u):>9d}")
PY