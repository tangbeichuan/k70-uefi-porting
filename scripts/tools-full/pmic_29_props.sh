#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
echo '===== strings containing prop/node/subnode/get_ (whole file)'
python3 - <<'EOF'
b=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi','rb').read()
import re
for m in re.finditer(rb'[ -~]{5,}', b):
    s=m.group().decode('ascii')
    if re.search(r'prop|Prop|subnode|get_|node|Node', s) and not s.startswith('.text'):
        print('0x%05x %r' % (m.start(), s))
EOF
echo '===== 1ed00-1ede0'
python3 pmic_an.py show 1ed00 1ede0
echo '===== 1f130-1f230'
python3 pmic_an.py show 1f130 1f230
