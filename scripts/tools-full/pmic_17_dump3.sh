#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
python3 pmic_an.py show 15180 152f0
echo '########## strings 0x2da40..0x2dab0'
python3 - <<'EOF'
efi=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi','rb').read()
off=0x2da40
while off < 0x2dab0:
    if 32<=efi[off]<127 and (off==0x2da40 or not (32<=efi[off-1]<127)):
        end=off
        while end<len(efi) and 32<=efi[end]<127: end+=1
        print('0x%06x: %r'%(off,efi[off:end].decode()))
        off=end
    else:
        off+=1
EOF
echo '########## tail 0x1f450-0x1f520'
python3 pmic_an.py show 1f450 1f520
