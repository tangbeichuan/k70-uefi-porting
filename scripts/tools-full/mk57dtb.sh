set +e
cd /mnt/d/_k70tmp
dtc -I dtb -O dts -o /tmp/t10168.dts xbl_config_fdt_10168.dtb 2>/dev/null
python3 - <<'PY'
p='/tmp/t10168.dts'
s=open(p,encoding='utf-8',errors='replace').read()
if 'pre-psi' in s:
    print('already has pre-psi')
else:
    lines=s.split('\n')
    out=[]; done=False
    for ln in lines:
        out.append(ln)
        if (not done) and ln.strip().startswith('pon {'):
            indent=ln[:len(ln)-len(ln.lstrip())]+'\t'
            out.append(indent+'pre-psi {')
            out.append(indent+'\tpre-psi-value = <0x00>;')
            out.append(indent+'};')
            done=True
    assert done, 'pon node not found'
    open(p,'w',encoding='utf-8').write('\n'.join(out))
    print('inserted pre-psi under pon')
PY
dtc -I dts -O dtb -o /mnt/d/_k70tmp/xbl_ufs_57.dtb /tmp/t10168.dts 2>&1 | tail -3
ls -l /mnt/d/_k70tmp/xbl_ufs_57.dtb
echo "=== verify ==="
dtc -I dtb -O dts /mnt/d/_k70tmp/xbl_ufs_57.dtb 2>/dev/null | grep -A2 'pre-psi {' | head -6
dtc -I dtb -O dts /mnt/d/_k70tmp/xbl_ufs_57.dtb 2>/dev/null | grep -c 'iort'