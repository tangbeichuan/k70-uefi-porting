set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
s = s.replace('    ConOut (Line);\n', '    Say (Line);\n', 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('ConOut -> Say fixed')
PY
grep -n "Say (Line);" "$F" | head -4