#!/usr/bin/env python3
import glob, os, struct, itertools, collections

D='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers'
consumers = ['DALTLMM','DisplayDxe','HALIOMMUDxe','I2CDxe','PmicDxe','QcomBds','RngDxe','SdccDxe','SPIDxe','UCDxe','UFSDxe','UsbConfigDxe','UsbDeviceDxe','UsbfnDwc3Dxe']

def efi(name):
    for p in glob.glob(f'{D}/{name}/*.efi'):
        return p
    for p in glob.glob(f'{D}/{name}/*/*.efi'):
        return p
    return None

files = {}
for c in consumers:
    p = efi(c)
    if p: files[c] = p
print('consumers found:', len(files))

def cands(path):
    d = open(path,'rb').read()
    out = set()
    # scan for plausible GUID blobs: 16 bytes, at 4-byte alignment
    for off in range(0, len(d)-16, 4):
        b = d[off:off+16]
        # heuristics: at least one of the 8-byte halves looks random-ish, not all zero/ff
        if b == b'\x00'*16 or b == b'\xff'*16: continue
        out.add(b)
    return out

sets = {k: cands(v) for k,v in files.items()}
inter = None
for k,s in sets.items():
    inter = s if inter is None else (inter & s)
print('intersection size:', len(inter) if inter else 0)

# non consumers: vendor dirs not in consumer list
allv = [os.path.basename(x) for x in glob.glob(f'{D}/*') if os.path.isdir(x)]
others = [v for v in allv if v not in consumers]
otherset = set()
for o in others:
    p = efi(o)
    if p:
        try: otherset |= cands(p)
        except Exception: pass
print('others:', len(others))

final = [g for g in inter if g not in otherset]
print('candidates after removing others:', len(final))

def fmt(b):
    d1,d2,d3 = struct.unpack('<IHH', b[:8])
    return '%08X-%04X-%04X-%s-%s' % (d1,d2,d3, b[8:10].hex().upper(), b[10:16].hex().upper())

for g in final[:25]:
    print(' ', fmt(g), g.hex())
