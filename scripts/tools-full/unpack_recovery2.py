import struct, zlib, io
p = r'D:\本地项目-01\_twrp\recovery_a.img'
d = open(p,'rb').read()
def u32(o): return struct.unpack_from('<I', d, o)[0]
assert d[:8]==b'ANDROID!'
ks = u32(8); rs = u32(12); osv = u32(16); hs = u32(20); hv = u32(40)
cmd = d[44:44+1536].split(b'\x00')[0].decode(errors='replace')
sig = u32(1580)
print('v=%d hdr_size=%d kernel=%d ramdisk=%d sig=%d os=0x%x' % (hv, hs, ks, rs, sig, osv))
print('cmdline=%r' % cmd[:250])
off = hs
kern = d[off:off+ks]; off += ks
rd   = d[off:off+rs]
open(r'D:\本地项目-01\_twrp\kernel.bin','wb').write(kern)
open(r'D:\本地项目-01\_twrp\ramdisk.img','wb').write(rd)
print('kernel magic=%s len=%d' % (kern[:4].hex(), len(kern)))
print('ramdisk magic=%s len=%d' % (rd[:4].hex(), len(rd)))
# 找 kernel 里的 gzip / dtb magic
for m,name in ((b'\x1f\x8b\x08','gzip'), (b'\xd0\x0d\xfe\xed','fdt'), (b'BZh','bzip2'), (b'\x5d\x00\x00','lzma'), (b'\x28\xb5\x2f\xfd','zstd')):
    print(name, kern.find(m))