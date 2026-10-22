#!/usr/bin/env python3
# confirm children of /sw/pmic/adc/vadc/spmi-vadc@7 in the source DTB (what +0x28 must report)
import struct, pathlib, sys

b = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb').read_bytes()
off_struct = struct.unpack('>I', b[8:12])[0]
off_str = struct.unpack('>I', b[12:16])[0]

def name_at(o):
    e = b.index(b'\0', o)
    return b[o:e].decode('latin1')

def be32(o):
    return struct.unpack('>I', b[o:o+4])[0]

def skip(o):
    # o points at FDT_BEGIN_NODE
    p = o + 4
    while b[p] != 0:
        p += 1
    p = (p + 4) & ~3
    depth = 1
    while depth:
        tok = be32(p)
        if tok == 1:
            depth += 1
            p += 4
            while b[p] != 0:
                p += 1
            p = (p + 4) & ~3
        elif tok == 2:
            depth -= 1
            p += 4
        elif tok == 3:
            ln = be32(p+4)
            p += 12 + ((ln + 3) & ~3)
        elif tok == 4:
            p += 4
        else:
            raise SystemExit('bad token %x at %x' % (tok, p))
    return p

path = sys.argv[1] if len(sys.argv) > 1 else '/sw/pmic/adc/vadc/spmi-vadc@7'
parts = [p for p in path.split('/') if p]
p = (off_struct + 4)
# skip root name (empty)
while b[p] != 0:
    p += 1
p = (p + 4) & ~3

cur = None
stack = []
depth_ok = True
for part in parts:
    found = 0
    while True:
        tok = be32(p)
        if tok == 1:
            nm = name_at(p+4)
            if nm == part:
                found = p
                p = p + 4
                while b[p] != 0:
                    p += 1
                p = (p + 4) & ~3
                break
            p = skip(p)
        elif tok == 2:
            break
        elif tok == 3:
            ln = be32(p+4)
            p += 12 + ((ln + 3) & ~3)
        elif tok == 4:
            p += 4
        elif tok == 9:
            break
        else:
            break
    if not found:
        raise SystemExit('NOT FOUND: %s' % part)
    cur = found
print('node offset 0x%x for %s' % (cur, path))
kids = []
while True:
    tok = be32(p)
    if tok == 1:
        kids.append(name_at(p+4))
        p = skip(p)
    elif tok == 3:
        ln = be32(p+4)
        p += 12 + ((ln + 3) & ~3)
    elif tok == 4:
        p += 4
    else:
        break
print('children count =', len(kids))
for i, k in enumerate(kids):
    print('  [%d] %s  (len+1=%d)' % (i, k, len(k)+1))
