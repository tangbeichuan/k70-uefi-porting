#!/usr/bin/env python3
import struct, glob, os
EFI='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi'
d=open(EFI,'rb').read()
g=d[0x1c278:0x1c288]
def fmt(b):
    d1,d2,d3=struct.unpack('<IHH',b[:8])
    return '%08X-%04X-%04X-%s-%s'%(d1,d2,d3,b[8:10].hex().upper(),b[10:16].hex().upper())
print('candidate protocol GUID =', fmt(g), '| raw', g.hex())
print()
# strings near the code that were used as args
for off in (0xbcd,0xbd8,0xbdc,0xbe6,0xbfc,0xc16,0xc30,0xc4a):
    s=d[0x1000+ ( (off+0x1000)-0x1000 ) :][:0]
# simpler: dump printable runs in .text from 0x1bbc0 to 0x1c300 by VA
va_start=0x1bbc0; va_end=0x1c320
seg=d[va_start:va_end]
out=[]
cur=[]
for i,b in enumerate(seg):
    if 32<=b<127:
        cur.append(chr(b))
    else:
        if len(cur)>=4: out.append((hex(va_start+i-len(cur)),''.join(cur)))
        cur=[]
print('strings in .text data area:')
for a,s in out: print('  ',a,repr(s))
print()
# who else in stock FV contains this GUID?
D='/mnt/d/本地项目-01/_k70port_extract/fv_dump'
hits=[]
for p in glob.glob(D+'/**/*.efi', recursive=True):
    try: dd=open(p,'rb').read()
    except Exception: continue
    if g in dd: hits.append((os.path.basename(p), len(dd), os.path.basename(os.path.dirname(p))))
print('stock FV modules containing the GUID:', len(hits))
for h in sorted(hits): print('  ', h)
