#!/usr/bin/env python3
# pmic_12_findguid.py : locate an EFI GUID's byte pattern in files
import sys, os, struct

def guid_bytes(s):
    parts = s.replace('{','').replace('}','').replace(',',' ').replace('-',' ').split()
    d1, d2, d3 = int(parts[0],16), int(parts[1],16), int(parts[2],16)
    rest = []
    for x in parts[3:]:
        if len(x) == 4:
            rest += [int(x[:2],16), int(x[2:],16)]
        elif len(x) == 12:
            rest += [int(x[i:i+2],16) for i in range(0,12,2)]
        else:
            rest.append(int(x,16))
    return struct.pack('<IHH', d1, d2, d3) + bytes(rest[:8])

root = sys.argv[1]
pat = guid_bytes(sys.argv[2])
for dirpath, dirnames, filenames in os.walk(root):
    for fn in filenames:
        p = os.path.join(dirpath, fn)
        try:
            data = open(p, 'rb').read()
        except Exception:
            continue
        off = 0
        hits = []
        while True:
            i = data.find(pat, off)
            if i < 0:
                break
            hits.append(i)
            off = i + 1
        if hits:
            print('%s : %s' % (p, ' '.join('0x%x' % h for h in hits)))
