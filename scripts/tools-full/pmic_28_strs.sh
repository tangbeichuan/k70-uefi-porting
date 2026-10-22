#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
python3 - <<'EOF'
b=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi','rb').read()
# dump printable strings between 0x2d400 and 0x2dc80
i=0x2d400
while i < 0x2dc80:
    c=b[i]
    if 0x20 <= c < 0x7f:
        j=i
        while j < len(b) and 0x20 <= b[j] < 0x7f: j+=1
        if b[j]==0 and j-i >= 4:
            print('0x%05x %r' % (i, b[i:j].decode('ascii')))
            i=j
    i+=1
EOF
