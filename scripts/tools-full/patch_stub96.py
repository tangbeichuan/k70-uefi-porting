import pathlib, shutil, re, sys

PKG = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
TOOLS = pathlib.Path('/mnt/d/本地项目-01/_tools')
drv_dir = PKG / 'Drivers' / 'VermeerSmmuStubDxe'
drv_dir.mkdir(parents=True, exist_ok=True)

for name in ('VermeerSmmuStubDxe.c', 'VermeerSmmuStubDxe.inf'):
    shutil.copyfile(TOOLS / name, drv_dir / name)

INF_REL = 'vermeerPkg/Drivers/VermeerSmmuStubDxe/VermeerSmmuStubDxe.inf'

# 1) dsc [Components]
dsc = PKG / 'vermeer.dsc'
s = dsc.read_text(encoding='utf-8')
if 'VermeerSmmuStubDxe' not in s:
    anchor = '  vermeerPkg/Drivers/VermeerUfsMapDxe/VermeerUfsMapDxe.inf\n'
    if anchor not in s:
        anchor = '  vermeerPkg/Drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.inf\n'
    assert anchor in s, 'dsc anchor not found'
    s = s.replace(anchor, anchor + '  ' + INF_REL + '\n', 1)
    dsc.write_text(s, encoding='utf-8')
    print('dsc: added')
else:
    print('dsc: already')

# 2) fdf
fdf = PKG / 'vermeer.fdf'
s = fdf.read_text(encoding='utf-8')
if 'VermeerSmmuStubDxe' not in s:
    idx = s.rfind('}')
    # 找到 [FV] 段内最后一个 INF 行之后插入
    m = list(re.finditer(r'^INF\s+vermeerPkg/Drivers/[^\n]*\n', s, re.M))
    if not m:
        print('fdf: no direct INF lines (uses APRIORI.inc include) - skip')
        m = None
    else:
        pass
    if m:
        last = m[-1]
        s = s[:last.end()] + 'INF ' + INF_REL + '\n' + s[last.end():]
        fdf.write_text(s, encoding='utf-8')
        print('fdf: added')
else:
    print('fdf: already')

# 3) APRIORI: 放在 UFSDxe 之前
apr = PKG / 'Include' / 'APRIORI.inc'
s = apr.read_text(encoding='utf-8')
if 'VermeerSmmuStubDxe' not in s:
    lines = s.split('\n')
    out = []
    inserted = False
    for line in lines:
        if (not inserted) and line.strip().startswith('INF') and 'UFSDxe' in line:
            out.append('INF ' + INF_REL)
            inserted = True
        out.append(line)
    assert inserted, 'UFSDxe line not found in APRIORI'
    apr.write_text('\n'.join(out), encoding='utf-8')
    print('apriori: added before UFSDxe')
else:
    print('apriori: already')