import io
src='/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys70.sh'
s=io.open(src,encoding='utf-8',errors='replace').read()
s=s.replace('TAG=${1:-keys70}','TAG=${1:-keys71}',1)
old='if "HALIOMMUDxe" in line and not line.lstrip().startswith("#"):'
new='if ("HALIOMMUDxe" in line or "UFSDxe" in line) and not line.lstrip().startswith("#"):'
assert old in s
s=s.replace(old,new,1)
s=s.replace('hard-dropped HALIOMMU lines:','hard-dropped HALIOMMU+UFSDxe lines:',1)
s=s.replace('# ---- 3b) 硬编码剔除 HALIOMMU（DROP token 机制对它无效，单独处理）',
            '# ---- 3b) 硬编码剔除 HALIOMMU + UFSDxe（本次直接用自研直读驱动）',1)
io.open('/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys71.sh','w',encoding='utf-8').write(s)
print('run_keys71.sh written')