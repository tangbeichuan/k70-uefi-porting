set +e
G=/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py
python3 - "$G" <<'PY'
import pathlib, sys, re
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8')
if 'keys112' in s:
    print('already patched'); raise SystemExit
s = s.replace('def gop(dsc, fdf):', 'def gop(dsc, fdf):\n    return  # keys112: SimpleFbDxe already shipped via Include/DXE.inc', 1)
p.write_text(s, encoding='utf-8'); print('disabled gop()')
PY
sed -n '213,220p' "$G"
python3 -c "import ast; ast.parse(open('/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py').read()); print('syntax OK')"