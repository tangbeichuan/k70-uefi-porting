#!/usr/bin/env bash
set +e
cd /root/k70/uefi || exit 1
echo "=== all .dec files containing FA5F306B / EB97088E / 4684800A ==="
grep -rn -E "FA5F306B|EB97088E|4684800A" --include='*.dec' . 2>/dev/null
echo
echo "=== any file (h/c) naming EB97088E ==="
grep -rIn -E "EB97088E-?|EB97088E" --include='*.h' --include='*.c' --include='*.md' --include='*.txt' . 2>/dev/null | head -10
echo
echo "=== GUID name list: who pushes EB97088E in depex? (search depex binaries) ==="
python3 - <<'PY'
import pathlib, struct
def gb(s):
    p=s.split('-')
    return struct.pack('<IHH',int(p[0],16),int(p[1],16),int(p[2],16))+bytes.fromhex(p[3]+p[4])
targets={'EB97088E':'EB97088E-CFDF-49C6-BE4B-D906A5B20E86','FA5F306B':'FA5F306B-F47D-4AC4-A47D-882F8204EC30'}
root=pathlib.Path('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers')
for k,v in targets.items():
    pat=gb(v)
    print('===',k,'depex hit drivers ===')
    for f in root.rglob('*.depex'):
        if pat in f.read_bytes():
            print('  ',f)
    print('===',k,'efi hit drivers (name only) ===')
    for f in root.rglob('*.efi'):
        if pat in f.read_bytes():
            print('  ',f)
    print()
PY
