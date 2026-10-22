import struct
p = r'D:\本地项目-01\_twrp\recovery_a.img'
d = open(p,'rb').read()
i = d.find(b'070701')
print('first cpio at abs', i)
# 有些版本前面有 4 字节对齐
def parse(off, limit=4000):
    out=[]
    n=0
    while off+110 <= len(d):
        if d[off:off+6] != b'070701': break
        hdr = d[off:off+110]
        namesize = int(hdr[94:102],16); filesize = int(hdr[54:62],16)
        name = d[off+110:off+110+namesize-1].decode(errors='replace')
        data_off = off+110+namesize
        data_off = (data_off + 3) & ~3
        out.append((name, filesize))
        if name == 'TRAILER!!!': break
        off = (data_off+filesize+3) & ~3
        n+=1
        if n>limit: break
    return out
ents = parse(i)
print('entries', len(ents))
for nm,sz in ents[:60]:
    print('%8d  %s' % (sz, nm))
print('--- fstab/init ---')
for nm,sz in ents:
    if any(k in nm.lower() for k in ('fstab','init','prop','dtb')):
        print('%8d  %s' % (sz, nm))