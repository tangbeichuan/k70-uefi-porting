set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys, re
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys120b' in s:
    print('already'); raise SystemExit
start = s.find('// keys120: full-screen status page (drawn, not printed)')
if start < 0:
    print('helper not found'); raise SystemExit(2)
end = s.find('STATIC\nVOID\nGuiMenu (\n  VOID\n  );', start)
if end < 0:
    print('end marker missing'); raise SystemExit(3)
block = s[start:end]
s = s[:start] + s[end:]
# insert before the GuiMenu definition body
m = re.search(r'STATIC\s*\nVOID\s*\nGuiMenu\s*\(\s*\n\s*VOID\s*\n\s*\)\s*\n\{', s)
if not m:
    print('definition not found'); raise SystemExit(4)
s = s[:m.start()] + '// keys120b\n' + block + s[m.start():]
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('moved status page after GuiRect/GuiText')
PY