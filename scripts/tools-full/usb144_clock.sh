#!/bin/bash
set +e
UEFI=/root/k70/uefi
echo "=== 1) Clock-related protocol GUIDs declared in .dec files ==="
grep -rhiE '^\s*g?[A-Za-z0-9_]*(Clock|clk)[A-Za-z0-9_]*Guid\s*=' $UEFI/QcomPkg $UEFI/Silicon $UEFI/Platforms --include=*.dec 2>/dev/null | head -10
grep -rhiE '^\s*g?[A-Za-z0-9_]*(Clock|clk)[A-Za-z0-9_]*Guid\s*=' $UEFI/QcomPkg $UEFI/Silicon $UEFI/Platforms --include=*.dec -A1 2>/dev/null | head -30

echo
echo "=== 2) ClockDxe in FV? (Guid.xref) ==="
grep -i 'clock' $UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref || echo "  NONE (ClockDxe not in FV)"

echo
echo "=== 3) ClockDxe binary exists? depex? dt paths? ==="
CD=$UEFI/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.efi
ls -l $CD 2>/dev/null
ls -l $UEFI/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/*.depex 2>/dev/null
echo "--- strings /soc paths + clock names ---"
strings $CD 2>/dev/null | grep -E '^/soc|/soc/|ClockProtocol|clock|gcc|usb3|usb30' | head -30

echo
echo "=== 4) UsbConfigDxe: which protocols does it Locate at runtime? (GUID table + names) ==="
python3 - <<'PY'
import re,subprocess
log=subprocess.run(['python3','/mnt/d/本地项目-01/_tools/guid_match.py',
  '/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi'],
  capture_output=True,text=True).stdout
print(log)
PY

echo
echo "=== 5) UsbBusDxe / UsbMsdDxe / UsbInitDxe depex ==="
for m in UsbBusDxe UsbMsdDxe UsbInitDxe UsbPwrCtrlDxe; do
  D=$UEFI/Binaries/vermeer/QcomPkg/Drivers/$m/$m.depex
  echo "--- $m"
  ls -l $D 2>/dev/null && python3 - "$D" <<'PY'
import sys,struct
d=open(sys.argv[1],'rb').read()
i=0;guids=[];ops=[]
while i<len(d):
    op=d[i];i+=1
    if op==0:ops.append('BEFORE')
    elif op==1:ops.append('AFTER')
    elif op==2:
        a,b,c=struct.unpack('<IHH',d[i:i+8]);t=d[i+8:i+16]
        guids.append('%08X-%04X-%04X-%s-%s'%(a,b,c,t[:2].hex().upper(),t[2:].hex().upper()));ops.append('PUSH');i+=16
    elif op==3:ops.append('AND')
    elif op==4:ops.append('OR')
    elif op==5:ops.append('NOT')
    elif op==6:ops.append('TRUE')
    elif op==7:ops.append('FALSE')
    elif op==8:ops.append('END');break
    else:ops.append('?%d'%op)
print('   ops:',' '.join(ops))
for g in guids:print('   ',g)
PY
done
