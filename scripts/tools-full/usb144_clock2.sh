#!/bin/bash
set +e
UEFI=/root/k70/uefi
CD=$UEFI/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.efi
echo "=== ClockDxe.depex (36 B) ==="
python3 - "$UEFI/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.depex" <<'PY'
import sys,struct
d=open(sys.argv[1],'rb').read()
i=0;ops=[]
while i<len(d):
    op=d[i];i+=1
    if op==0:ops.append('BEFORE')
    elif op==1:ops.append('AFTER')
    elif op==2:
        a,b,c=struct.unpack('<IHH',d[i:i+8]);t=d[i+8:i+16]
        ops.append('PUSH(%08X-%04X-%04X-%s-%s)'%(a,b,c,t[:2].hex().upper(),t[2:].hex().upper()));i+=16
    elif op==3:ops.append('AND')
    elif op==4:ops.append('OR')
    elif op==5:ops.append('NOT')
    elif op==6:ops.append('TRUE')
    elif op==7:ops.append('FALSE')
    elif op==8:ops.append('END');break
    else:ops.append('?%d'%op)
print('  ',' '.join(ops))
PY
echo
echo "=== ClockDxe: DT node paths it reads (DTBExtn) ==="
strings -t x "$CD" | grep -E '/soc|/sw/|dtb|DTBExtn|DtbExtn' | head -20
echo
echo "=== ClockDxe: NPA / RPMH / DTBExtn GUID presence (hex) ==="
python3 - "$CD" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
for name,h in [('DTBExtn','76b789035f62eb1183bec741a913de34'),
               ('NPA?27ABF055','55f0ab27b8b1264c8048748f37baa2df'),
               ('RPMH?','')]:
    if not h: continue
    print('  %-12s %s'%(name, bytes.fromhex(h) in d))
# dump guids near .data (VA 0x?) via dec matching
PY
python3 /mnt/d/本地项目-01/_tools/guid_match.py "$CD" 2>/dev/null | head -30
echo
echo "=== ClockDxe in keys102/keys140 DROP list? ==="
grep -n 'clockdxe' /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys143b.sh | head -3
echo
echo "=== current FV: any module producing gEfiClockProtocolGuid 241AFAE6? ==="
FV=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
python3 - "$FV" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
g=bytes.fromhex('e6fa1a248f5f6c4fa7eac28eab79c3e5')
print('  241AFAE6 occurrences in FVMAIN.Fv:',d.count(g))
PY
