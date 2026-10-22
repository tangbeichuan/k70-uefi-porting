set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
proto = 'STATIC\nVOID\nSay (\n  CONST CHAR16  *Text\n  );\n\n'
if 'STATIC\nVOID\nSay (\n  CONST CHAR16  *Text\n  );\n\n' in s:
    print('forward decl exists'); raise SystemExit
# insert forward declaration right after the includes block (before first STATIC CONST EFI_GUID)
idx = s.find('STATIC CONST EFI_GUID mSimpleFbGuid')
if idx < 0:
    idx = s.find('STATIC BOOLEAN  mGopPresent')
s = s[:idx] + proto + s[idx:]
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('forward decl added')
PY
sed -n '30,45p' "$F"