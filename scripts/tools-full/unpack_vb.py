import struct, io
out=io.open(r'D:\本地项目-01\_twrp\parse2.txt','w',encoding='utf-8')
def P(*a): out.write(' '.join(str(x) for x in a)+'\n')
def u32(d,o): return struct.unpack_from('<I',d,o)[0]
def u64(d,o): return struct.unpack_from('<Q',d,o)[0]
def cl(x,pg): return (x+pg-1)//pg*pg if x else 0
v=open(r'D:\本地项目-01\_twrp\Image\vendor_boot_a.img','rb').read()
hv=u32(v,8); pg=u32(v,12); vrs=u32(v,24)
tags=u32(v,2076); hsz=u32(v,2096); ds=u32(v,2100); da=u64(v,2104)
P('vendor_boot v%d page=%d header_size=%d vendor_ramdisk=%d tags=0x%x dtb_size=%d dtb_addr=0x%x' % (hv,pg,hsz,vrs,tags,ds,da))
cmd=v[28:28+2048].split(b'\x00')[0].decode(errors='replace')
P('cmdline=', cmd[:400])
off=hsz
rd=v[off:off+vrs]; off+=cl(vrs,pg)
dtb=v[off:off+ds]
P('ramdisk head=', rd[:8].hex(), 'len=', len(rd))
P('dtb magic=', dtb[:4].hex(), 'len=', len(dtb))
open(r'D:\本地项目-01\_twrp\Image\vendor_boot.dtb','wb').write(dtb)
open(r'D:\本地项目-01\_twrp\Image\vendor_boot.ramdisk','wb').write(rd)
out.close(); print('done')