set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys84/keys88/g; s/bak84/bak88/g' run_keys84.sh > run_keys88.sh
python3 - <<'PY'
import pathlib
p=pathlib.Path('run_keys88.sh'); s=p.read_text(encoding='utf-8')
old='python3 /mnt/d/本地项目-01/_tools/patch_ufsmap84.py "$PKG"'
assert old in s
s=s.replace(old, old + '\npython3 /mnt/d/本地项目-01/_tools/move_probe88.py "$PKG/Include/APRIORI.inc"', 1)
p.write_text(s,encoding='utf-8'); print('injected probe-move')
PY
bash run_keys88.sh keys88 > /tmp/k88.log 2>&1; echo "run exit=$?"
grep -nE 'apriori: probe moved|ERROR|PROGRESS - Success' /tmp/k88.log | head -5
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys88.fd" keys88 2>&1 | tail -3