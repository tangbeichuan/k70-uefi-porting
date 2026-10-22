import pathlib
apr = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc')
s = apr.read_text(encoding='utf-8')
line = 'INF vermeerPkg/Apps/VermeerStage2App/VermeerStage2App.inf'
if line not in s:
    s = s.rstrip('\n') + '\n' + line + '\n'
    apr.write_text(s, encoding='utf-8')
    print('apriori: app INF appended')
else:
    print('apriori: app already')