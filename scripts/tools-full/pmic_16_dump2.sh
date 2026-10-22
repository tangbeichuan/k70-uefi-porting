#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
python3 pmic_an.py show 1f260 1f450
echo '########## strings in 0x2d9b0..0x2da40 and format 0x2dad7'
python3 - <<'EOF'
efi=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi','rb').read()
for off in range(0x2d9a0,0x2da40):
    c=efi[off]
    if 32<=c<127:
        if off==0x2d9a0 or not (32<=efi[off-1]<127):
            end=off
            while end<len(efi) and 32<=efi[end]<127: end+=1
            print('0x%06x: %r'%(off,efi[off:end].decode()))
print('--- 0x2dad7:', repr(efi[0x2dad7:0x2dad7+60]))
EOF
