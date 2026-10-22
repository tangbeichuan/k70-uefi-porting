set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
lines = p.read_text(encoding='utf-8', errors='surrogateescape').splitlines(True)
# lines are 0-based; helper occupies lines 82..(up to the three blank lines before 'STATIC CONST EFI_GUID mSimpleFbGuid')
start = None; end = None
for i, l in enumerate(lines):
    if l.startswith('// keys120: full-screen status page'):
        start = i
    if start is not None and l.startswith('STATIC CONST EFI_GUID mSimpleFbGuid'):
        end = i
        break
if start is None or end is None:
    print('markers missing', start, end); raise SystemExit(2)
block = lines[start:end]
# trim trailing blank lines from block
while block and block[-1].strip() == '':
    block.pop()
del lines[start:end]
# find GuiMenu definition line (the one after GuiText body) => line starting with 'GuiMenu (' after index of 'GuiText ('
gi = next(i for i, l in enumerate(lines) if l.startswith('GuiText ('))
gm = next(i for i, l in enumerate(lines) if i > gi and l.startswith('GuiMenu ('))
insert_at = gm - 2   # 'STATIC' / 'VOID' precede it
if 'STATIC' not in lines[insert_at] and 'STATIC' not in lines[insert_at-1]:
    insert_at = gm - 1
new = block + ['\n']
lines[insert_at:insert_at] = new
p.write_text(''.join(lines), encoding='utf-8', errors='surrogateescape')
print('moved; inserted at line', insert_at + 1)
PY
grep -n "^GuiRect (\|^GuiText (\|^GuiStatusPage (\|^GuiMenu (" "$F"