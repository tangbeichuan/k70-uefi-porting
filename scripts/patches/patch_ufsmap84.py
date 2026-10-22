import pathlib, sys
pkg = pathlib.Path(sys.argv[1])   # Platforms/Xiaomi/vermeerPkg
src = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerUfsMapDxe')
dst = pkg / 'Drivers' / 'VermeerUfsMapDxe'
dst.mkdir(parents=True, exist_ok=True)
for n in ('VermeerUfsMapDxe.c','VermeerUfsMapDxe.inf'):
    (dst/n).write_text((src/n).read_text(encoding='utf-8'), encoding='utf-8')

INF_REL = 'vermeerPkg/Drivers/VermeerUfsMapDxe/VermeerUfsMapDxe.inf'

# dsc
dsc = pkg/'vermeer.dsc'
t = dsc.read_text(encoding='utf-8')
if INF_REL not in t:
    lines = t.splitlines(keepends=True)
    out=[]; done=False
    for i,l in enumerate(lines):
        out.append(l)
        if not done and 'VermeerDtbExtnDxe.inf' in l:
            out.append('  ' + INF_REL + '\n'); done=True
    if not done:
        for i,l in enumerate(out):
            if l.strip().startswith('DxeMain.inf'):
                out.insert(i+1, '  ' + INF_REL + '\n'); done=True; break
    dsc.write_text(''.join(out), encoding='utf-8'); print('dsc: added')

# fdf
fdf = pkg/'vermeer.fdf'
t = fdf.read_text(encoding='utf-8')
if INF_REL not in t:
    lines = t.splitlines(keepends=True); out=[]; done=False
    for l in lines:
        out.append(l)
        if not done and 'VermeerDtbExtnDxe.inf' in l:
            out.append('  INF ' + INF_REL + '\n'); done=True
    fdf.write_text(''.join(out), encoding='utf-8'); print('fdf: added', done)

# APRIORI: 放在 UFSDxe 之前
ap = pkg/'Include'/'APRIORI.inc'
t = ap.read_text(encoding='utf-8')
if INF_REL not in t:
    lines = t.splitlines(keepends=True); out=[]; done=False
    for l in lines:
        if (not done) and 'UFSDxe.inf' in l:
            out.append('  INF ' + INF_REL + '\n'); done=True
        out.append(l)
    if not done:
        # 退路：紧跟 Pcd.inf
        out=[]; done=False
        for l in lines:
            out.append(l)
            if (not done) and 'PCD/Dxe/Pcd.inf' in l:
                out.append('  INF ' + INF_REL + '\n'); done=True
    ap.write_text(''.join(out), encoding='utf-8'); print('apriori: added', done)
print('ufsmap patch done')