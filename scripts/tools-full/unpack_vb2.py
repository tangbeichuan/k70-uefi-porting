import struct, io
def u32(d,o): return struct.unpack_from('<I',d,o)[0]
def cl(x,pg): return (x+pg-1)//pg*pg if x else 0
v=open(r'D:\本地项目-01\_twrp\Image\vendor_boot_a.img','rb').read()
pg=u32(v,12); vrs=u32(v,24); hsz=u32(v,2096); ds=u32(v,2100)
off=cl(hsz,pg)
off+=cl(vrs,pg)
dtb=v[off:off+ds]
open(r'D:\本地项目-01\_twrp\Image\vendor_boot.dtb','wb').write(dtb)
print('dtb magic=', dtb[:4].hex(), 'len=', len(dtb))
print('count FDT magic in region:', dtb.count(b'\xd0\x0d\xfe\xed') + dtb.count(b'\x00\x0d\x0d\xf0'))