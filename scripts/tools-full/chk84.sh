set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys80/keys84/g; s/bak80/bak84/g' run_keys80.sh > run_keys84.sh
python3 - <<'PY'
import pathlib
p=pathlib.Path('run_keys84.sh'); s=p.read_text(encoding='utf-8')
old='# ---- 4) 编译 + 打包 -------------------------------------------------------------'
assert old in s
s=s.replace(old, 'python3 /mnt/d/本地项目-01/_tools/patch_ufsmap84.py "$PKG"\n\n'+old, 1)
p.write_text(s,encoding='utf-8'); print('run_keys84 injected')
PY
bash run_keys84.sh keys84 > /tmp/k84.log 2>&1; echo "run exit=$?"
grep -nE 'ufsmap patch|dsc: added|fdf: added|apriori: added|kept vendor|error:|PROGRESS - Success' /tmp/k84.log | tail -8
grep -iE 'VermeerUfsMapDxe|UFSDxe|PmicDxe|HALIOMMUDxe' /tmp/guid-keys84.xref 2>/dev/null || true
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys84.fd" keys84 2>&1 | tail -3