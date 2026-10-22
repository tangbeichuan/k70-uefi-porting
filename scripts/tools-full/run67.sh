set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 - <<'PY'
import io,re
src='/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh'
s=io.open(src,encoding='utf-8',errors='replace').read()
s=s.replace('TAG=${1:-keys57}','TAG=${1:-keys67}',1)
# 去掉 ufsdxe 的 drop，加上 pmicdxe
s=s.replace('"rngdxe", "tsens", "clockdxe", "displaydxe", "rammanagerdxe", "ufsdxe",',
            '"rngdxe", "tsens", "clockdxe", "displaydxe", "rammanagerdxe",\n    "pmicdxe",   # keys67: 绕开 PmicDxe 这个墙（0xa0 名字查询把它打崩）')
io.open('/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys67.sh','w',encoding='utf-8').write(s)
print('run_keys67.sh written')
PY
bash run_keys67.sh keys67 2>&1 | tail -12