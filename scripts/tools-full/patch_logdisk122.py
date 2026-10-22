import pathlib, shutil

pkg = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
src = pathlib.Path('/mnt/d/本地项目-01/_tools')

dst = pkg / 'Drivers' / 'VermeerLogDiskDxe'
dst.mkdir(parents=True, exist_ok=True)
for name in ('VermeerLogDiskDxe.c', 'VermeerLogDiskDxe.inf'):
    shutil.copy2(src / name, dst / name)
print('copied driver ->', dst)

apr = pkg / 'Include' / 'APRIORI.inc'
a = apr.read_text(encoding='utf-8')
line = 'INF vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.inf'
if line in a:
    print('apriori: logdisk already present')
else:
    a = a.rstrip('\n') + '\n' + line + '\n'
    apr.write_text(a, encoding='utf-8')
    print('apriori: logdisk appended')

dsc = pkg / 'vermeer.dsc'
s = dsc.read_text(encoding='utf-8')
marker = '  vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.inf'
if marker not in s:
    idx = s.rfind('[Components]')
    end = s.find('\n[', idx + 10)
    if end < 0:
        end = len(s)
    s = s[:end] + marker + '\n' + s[end:]
    dsc.write_text(s, encoding='utf-8')
    print('dsc: added logdisk')
else:
    print('dsc: logdisk already present')
