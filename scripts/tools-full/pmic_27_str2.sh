#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
echo '===== strings 2b780-2b800, 2d880-2db00'
python3 - <<'EOF'
b=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi','rb').read()
def s(off):
    e=b.find(b'\x00',off)
    try: return b[off:e].decode('ascii','replace')
    except: return '?'
for off in [0x2b7ba,0x2d896,0x2d8a1,0x2d9e1,0x2d9ef,0x2d9fe,0x2da0b,0x2da20,0x2da30,0x2da40,0x2da49,0x2da57,0x2da61,0x2da6d,0x2da74,0x2da92,0x2daa8,0x2dab9,0x2dac8,0x2dad7,0x2dae3]:
    print(hex(off), repr(s(off)))
EOF
echo '===== dts 2140-2200'
sed -n '2140,2200p' /tmp/xbl_ufs.dts
echo '===== gaps 1f444-1f520'
python3 pmic_an.py show 1f444 1f520
echo '===== 1f074-1f114 (per-channel parser?)'
python3 pmic_an.py show 1f074 1f114
