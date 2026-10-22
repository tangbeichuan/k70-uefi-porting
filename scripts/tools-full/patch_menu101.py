import pathlib, shutil, re

pkg = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
src = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe')

dst = pkg / 'Drivers' / 'VermeerMenuDxe'
dst.mkdir(parents=True, exist_ok=True)
for f in src.glob('*'):
    shutil.copy2(f, dst / f.name)

apr = pkg / 'Include' / 'APRIORI.inc'
a = apr.read_text(encoding='utf-8')

kept = []
removed = []
for ln in a.splitlines(True):
    body = ln.strip()
    if body.startswith('INF ') and ('Vermeer' in body):
        removed.append(body)
        continue
    kept.append(ln)
a = ''.join(kept).rstrip('\n') + '\nINF vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf\n'
apr.write_text(a, encoding='utf-8')
print('apriori: removed stale Vermeer lines ->', len(removed))
for r in removed:
    print('   -', r)
print('apriori: menu appended')

# dsc: keep [Components] consistent with what APRIORI references
dsc = pkg / 'vermeer.dsc'
s = dsc.read_text(encoding='utf-8')
marker = '  vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf'
if marker not in s:
    idx = s.rfind('[Components]')
    end = s.find('\n[', idx + 10)
    if end < 0:
        end = len(s)
    s = s[:end] + marker + '\n' + s[end:]
    dsc.write_text(s, encoding='utf-8')
    print('dsc: added menu')
else:
    print('dsc: menu already present')