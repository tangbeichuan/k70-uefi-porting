import io
p='/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c'
s=io.open(p,encoding='utf-8',errors='replace').read()
if '[UFS71] sending TUR' not in s:
    old='''  Ocs    = 0xFF;
  Status = 0xFF;
  Rc     = UfsScsi (0, 0, 0, &Ocs, &Status);'''
    new='''  UfsPrint ("[UFS71] sending TUR (first doorbell)...\\n");
  Ocs    = 0xFF;
  Status = 0xFF;
  Rc     = UfsScsi (0, 0, 0, &Ocs, &Status);'''
    assert old in s
    s=s.replace(old,new,1)
    io.open(p,'w',encoding='utf-8').write(s)
    print('doorbell marker added')
else:
    print('already there')

# run_keys73 = run_keys71 但只剔除 HALIOMMU（保留 UFSDxe 去初始化时钟/主机）
src='/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys71.sh'
t=io.open(src,encoding='utf-8',errors='replace').read()
t=t.replace('TAG=${1:-keys71}','TAG=${1:-keys73}',1)
t=t.replace('if ("HALIOMMUDxe" in line or "UFSDxe" in line) and not line.lstrip().startswith("#"):',
            'if ("HALIOMMUDxe" in line) and not line.lstrip().startswith("#"):',1)
t=t.replace('hard-dropped HALIOMMU+UFSDxe lines:','hard-dropped HALIOMMU lines:',1)
io.open('/mnt/d/本地项目-01/_k70port_extract/wsl/run_keys73.sh','w',encoding='utf-8').write(t)
print('run_keys73.sh written')