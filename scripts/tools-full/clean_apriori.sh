set +e
A=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
cp "$A" /tmp/APRIORI.inc.bak.pre111
python3 - <<'PY'
import pathlib
p = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc')
lines = p.read_text(encoding='utf-8', errors='surrogateescape').splitlines(True)
kept = [l for l in lines if 'SimpleFbDxe.inf' not in l]
p.write_text(''.join(kept), encoding='utf-8', errors='surrogateescape')
print('removed lines:', len(lines) - len(kept))
PY
grep -c "SimpleFbDxe" "$A"
# clear stale /tmp backups so the build cannot restore the duplicate
rm -f /tmp/APRIORI.inc.bak* /tmp/vermeer.fdf.bak* /tmp/vermeer.dsc.bak* 2>/dev/null
echo "backups cleared"