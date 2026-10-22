set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys95/keys96/g; s/bak95/bak96/g' run_keys95.sh > run_keys96.sh
# 在编译前注入 stub 注册
python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys96.sh')
s = p.read_text(encoding='utf-8', errors='surrogateescape')
anchor = '# ---- 4) 编译 + 打包'
assert anchor in s, 'anchor missing'
if 'patch_stub96.py' not in s:
    s = s.replace(anchor, 'python3 /mnt/d/本地项目-01/_tools/patch_stub96.py\n' + anchor, 1)
    p.write_text(s, encoding='utf-8')
    print('injected patch_stub96')
else:
    print('already injected')
PY
bash run_keys96.sh 2>&1 | tail -30