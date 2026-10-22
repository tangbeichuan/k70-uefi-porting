set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys117fwd' in s:
    print('already'); raise SystemExit
fwd = '''
STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL   *mGuiGop;      // keys117fwd
STATIC
VOID
GuiMenu (
  VOID
  );
'''
anchor = 'STATIC\nVOID\nSay (\n  CONST CHAR16  *Text\n  );\n'
if anchor in s:
    s = s.replace(anchor, anchor + fwd, 1)
else:
    s = s.replace('STATIC BOOLEAN  mGopPresent', fwd + 'STATIC BOOLEAN  mGopPresent', 1)
# remove duplicate definition of mGuiGop later
s = s.replace('STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL   *mGuiGop = NULL;\n', '', 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('forward decls added')
PY
& 'C:\Windows\System32\wsl.exe' -d Ubuntu -u root -- bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys117.sh 2>&1 | Select-Object -Last 8