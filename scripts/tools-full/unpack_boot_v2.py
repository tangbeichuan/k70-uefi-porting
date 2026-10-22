import struct, sys, io
out = io.open(r'D:\本地项目-01\_twrp\parse.txt','w',encoding='utf-8')
def P(*a):
    out.write(' '.join(str(x) for x in a)+'\n')
def u32(d,o): return struct.unpack_from('<I', d, o)[0]
def cl(x,pg): return (x+pg-1)//pg*pg if x else 0

b=open(r'D:\本地项目-01\_twrp\Image\boot_a.img','rb').read()
hv=u32(b,40); ks=u32(b,8); rs=u32(b,12); hs=u32(b,20)
P('boot v%d kernel=%d ramdisk=%d hdr=%d' % (hv,ks,rs,hs))
kern=b[hs:hs+ks]
P('kernel first16:', kern[:16].hex())
for m,n in ((b'\x1f\x8b\x08','gzip'),(b'\x28\xb5\x2f\xfd','zstd'),(b'\xfd7zXZ','xz'),(b'BZh','bzip2'),(b'ARMd','arm64-image-magic')):
    P('  ',n,'at',kern.find(m))
i=kern.find(b'Linux version ')
j=kern.find(b'6.1.')
P('Linux version str at', i)
for s in (b'ufshcd', b'init_speed_params', b'ufs-qcom', b'qcom,ufs', b'spm-level', b'gear'):
    P('  kernel contains', s.decode(), '->', kern.find(s))

v=open(r'D:\本地项目-01\_twrp\Image\vendor_boot_a.img','rb').read()
P('vendor_boot magic', v[:8], 'size', len(v))
hv2=u32(v,8); pg=u32(v,12); osv=u32(v,16); hs2=u32(v,20)
P('vendor v%d page=%d hdr=%d' % (hv2,pg,hs2))
cmd=v[24:24+2048].split(b'\x00')[0].decode(errors='replace')
P('cmdline=', cmd[:400])
# v3/v4 vendor_boot header layout: page_size, kernel_addr, ramdisk_addr, vendor_ramdisk_size, cmdline[2048], tags_addr, name[16], header_size, dtb_size, dtb_addr
vrs=u32(v,2088)   # vendor_ramdisk_size
tags=u32(v,2076)
P('vendor_ramdisk_size=', vrs, 'tags=', hex(tags))
if hv2>=3:
    ds=u32(v,2112); da=u32(v,2116)
    P('dtb_size=', ds, 'dtb_addr=', hex(da))
    off=hs2
    rd=v[off:off+vrs]; off+=cl(vrs,pg)
    dtb=v[off:off+ds]
    open(r'D:\本地项目-01\_twrp\Image\vendor_boot.dtb','wb').write(dtb)
    open(r'D:\本地项目-01\_twrp\Image\vendor_boot.ramdisk','wb').write(rd)
    P('dtb magic=', dtb[:4].hex(), 'len=', len(dtb))
    P('dtb contains ufs0:', dtb.find(b'ufs0'), 'ufshc:', dtb.find(b'ufshc'), 'init_speed_params:', dtb.find(b'init_speed_params'))
out.close()
print('done')