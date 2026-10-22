set +e
INF=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf
python3 - <<'PY'
import pathlib
p=pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf')
s=p.read_text(encoding='utf-8')
if 'DxeServicesLib' not in s:
    lines=s.split('\n')
    # 在 [LibraryClasses] 段末尾插入
    idx=None
    for i,l in enumerate(lines):
        if l.strip()=='[LibraryClasses]':
            j=i+1
            while j<len(lines) and lines[j].strip() and not lines[j].strip().startswith('['):
                j+=1
            idx=j
            break
    assert idx is not None
    lines.insert(idx,'  DxeServicesLib')
    p.write_text('\n'.join(lines),encoding='utf-8')
    print('inf: DxeServicesLib added')
else:
    print('inf: already')
PY
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash run_keys100.sh 2>&1 | tail -10