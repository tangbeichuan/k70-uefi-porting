set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 /mnt/d/本地项目-01/_tools/patch_probe100b.py
sed 's/keys99/keys100/g; s/bak99/bak100/g' run_keys99.sh > run_keys100.sh
python3 - <<'PY'
import pathlib
p=pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys100.sh')
s=p.read_text(encoding='utf-8',errors='surrogateescape')
a='# ---- 4) 编译 + 打包'
assert a in s
if 'patch_app100.py' not in s:
    s=s.replace(a,'python3 /mnt/d/本地项目-01/_tools/patch_app100.py\n'+a,1)
    p.write_text(s,encoding='utf-8'); print('injected app registration')
PY
bash run_keys100.sh 2>&1 | tail -12