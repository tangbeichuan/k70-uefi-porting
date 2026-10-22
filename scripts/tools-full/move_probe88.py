import pathlib, sys
ap = pathlib.Path(sys.argv[1])
INF = '  INF vermeerPkg/Drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf\n'
lines = ap.read_text(encoding='utf-8').splitlines(keepends=True)
if 'VermeerKeyProbeDxe' in ''.join(lines):
    print('probe already in APRIORI')
    sys.exit(0)
out=[]; done=False
for l in lines:
    out.append(l)
    if (not done) and ('PCD/Dxe/Pcd.inf' in l):
        out.append(INF); done=True
if not done:
    out = [INF] + lines
ap.write_text(''.join(out), encoding='utf-8')
print('apriori: probe inserted after Pcd.inf =', done)