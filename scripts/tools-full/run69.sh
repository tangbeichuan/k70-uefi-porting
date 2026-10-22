set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 - <<'PY'
import io
src='/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys67.sh'
s=io.open(src,encoding='utf-8',errors='replace').read()
s=s.replace('TAG=${1:-keys67}','TAG=${1:-keys69}',1)
s=s.replace('"pmicdxe",   # keys67: 绕开 PmicDxe 这个墙（0xa0 名字查询把它打崩）',
            '"pmicdxe",   # keys67: 绕开 PmicDxe 这个墙（0xa0 名字查询把它打崩）\n    "halionmu",  # keys69: HALIOMMU 要的是 ACPI IORT 表，不是 DT，必然失败后跳 0')
io.open('/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys69.sh','w',encoding='utf-8').write(s)
print('run_keys69.sh written')
PY
bash run_keys69.sh keys69 2>&1 | tail -10
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys69.fd" keys69 2>&1 | tail -3