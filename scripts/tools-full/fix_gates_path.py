import pathlib
g = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py')
s = g.read_text(encoding='utf-8')
s = s.replace('Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf',
              'SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf')
g.write_text(s, encoding='utf-8')
import re
for m in re.finditer(r'.*SimpleFbDxe.*', s):
    print('  ', m.group(0).strip())