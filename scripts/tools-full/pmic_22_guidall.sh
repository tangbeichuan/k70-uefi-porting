#!/bin/bash
# find all FV drivers containing DTBExtn GUID 0389B776-625F-11EB-83BE-C741A913DE34
D=/mnt/d/本地项目-01/_k70port_extract/fv_dump/drivers
cd "$D" || exit 1
python3 - <<'EOF'
import os, glob
g = bytes.fromhex('76b78903 5f62 eb11 83be c741a913de34'.replace(' ',''))
hits=[]
for f in sorted(glob.glob('/mnt/d/本地项目-01/_k70port_extract/fv_dump/drivers/*.efi')):
    try: b=open(f,'rb').read()
    except: continue
    off=-1
    while True:
        off=b.find(g, off+1)
        if off<0: break
        hits.append((os.path.basename(f), off))
for h in hits: print('%-28s off=0x%x' % h)
EOF
echo '---- protocol producer check: search for GUID + nearby "Install" strings not feasible; instead list all efi names'
ls /mnt/d/本地项目-01/_k70port_extract/fv_dump/drivers/ | tr '\n' ' '
echo
echo '---- other fv dirs?'
ls /mnt/d/本地项目-01/_k70port_extract/fv_dump/
