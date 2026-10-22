import pathlib, shutil, re
PKG = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
TOOLS = pathlib.Path('/mnt/d/本地项目-01/_tools')

app_dir = PKG / 'Apps' / 'VermeerStage2App'
app_dir.mkdir(parents=True, exist_ok=True)
for n in ('VermeerStage2App.c', 'VermeerStage2App.inf'):
    shutil.copyfile(TOOLS / n, app_dir / n)

APP_REL = 'vermeerPkg/Apps/VermeerStage2App/VermeerStage2App.inf'

dsc = PKG / 'vermeer.dsc'
s = dsc.read_text(encoding='utf-8')
if 'VermeerStage2App' not in s:
    anchor = '  vermeerPkg/Drivers/VermeerSmmuStubDxe/VermeerSmmuStubDxe.inf\n'
    if anchor not in s:
        anchor = '  vermeerPkg/Drivers/VermeerUfsMapDxe/VermeerUfsMapDxe.inf\n'
    assert anchor in s, 'dsc anchor'
    s = s.replace(anchor, anchor + '  ' + APP_REL + '\n', 1)
    dsc.write_text(s, encoding='utf-8')
    print('dsc: app added')
else:
    print('dsc: app already')

fdf = PKG / 'vermeer.fdf'
s = fdf.read_text(encoding='utf-8')
if 'VermeerStage2App' not in s:
    m = list(re.finditer(r'^INF\s+vermeerPkg/Drivers/[^\n]*\n', s, re.M))
    if m:
        last = m[-1]
        s = s[:last.end()] + 'INF ' + APP_REL + '\n' + s[last.end():]
        fdf.write_text(s, encoding='utf-8')
        print('fdf: app INF inserted')
    else:
        print('fdf: no driver INF anchor, skipped')
else:
    print('fdf: app already')