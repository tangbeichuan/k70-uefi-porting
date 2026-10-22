set +e
cd /mnt/d/_k70tmp
python3 - <<'PY'
src='/mnt/d/_k70tmp/xbl_config_fdt_10168.dtb'
import subprocess
dts=subprocess.run(['dtc','-I','dtb','-O','dts',src],capture_output=True,text=True).stdout
assert dts, 'dtc failed'
if 'pre-psi' in dts:
    print('already')
else:
    lines=dts.split('\n'); out=[]; state=0; depth=0; ins=False
    for ln in lines:
        s=ln.strip()
        if state==0 and s.startswith('pon {'):
            state=1; depth=0; ins=True
        if state==1:
            depth += ln.count('{') - ln.count('}')
            if ins and depth==0 and s in ('};','}'):
                indent=ln[:len(ln)-len(ln.lstrip())]+'\t'
                out.append(indent+'pre-psi {')
                out.append(indent+'\tpre-psi-value = <0x00>;')
                out.append(indent+'};')
                ins=False; state=2
        out.append(ln)
    assert state==2, 'pon block not found/closed'
    open('/tmp/t57.dts','w').write('\n'.join(out))
    print('inserted pre-psi before pon close')
PY
dtc -I dts -O dtb -o /mnt/d/_k70tmp/xbl_ufs_57.dtb /tmp/t57.dts 2>&1 | tail -3
ls -l /mnt/d/_k70tmp/xbl_ufs_57.dtb 2>/dev/null
dtc -I dtb -O dts /mnt/d/_k70tmp/xbl_ufs_57.dtb 2>/dev/null | grep -B1 -A2 'pre-psi {' | head -8
echo "iort nodes: $(dtc -I dtb -O dts /mnt/d/_k70tmp/xbl_ufs_57.dtb 2>/dev/null | grep -c 'iort')"