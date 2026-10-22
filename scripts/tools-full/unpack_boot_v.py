import struct
def u32(d,o): return struct.unpack_from('<I', d, o)[0]
def cl(x,pg): return (x+pg-1)//pg*pg if x else 0

def parse_boot(path, tag):
    d=open(path,'rb').read()
    print('=== %s  size=%d  magic=%r' % (tag, len(d), d[:8]))
    if d[:8]==b'ANDROID!':
        hv=u32(d,40)
        if hv>=3:
            ks=u32(d,8); rs=u32(d,12); hs=u32(d,20); sig=u32(d,1580)
            cmd=d[44:44+1536].split(b'\x00')[0].decode(errors='replace')
            print('boot v%d kernel=%d ramdisk=%d hdr=%d sig=%d' % (hv,ks,rs,hs,sig))
            print('cmdline=%r' % cmd[:200])
            off=hs; kern=d[off:off+ks]; off+=ks; rd=d[off:off+rs]
            open(path+'.kernel','wb').write(kern)
            open(path+'.ramdisk','wb').write(rd)
            print('kernel head=%s len=%d' % (kern[:4].hex(), len(kern)))
            i=kern.find(b'Linux version')
            print('Linux version in kernel at', i, repr(kern[i:i+80]) if i>0 else '')
        else:
            ks=u32(d,8); rs=u32(d,16); pg=u32(d,36)
            print('legacy boot v%d kernel=%d ramdisk=%d page=%d' % (hv,ks,rs,pg))
    elif d[:8]==b'VNDRBOOT':
        hv=u32(d,8); pg=u32(d,12); osv=u32(d,16); hs=u32(d,20)
        cmd=d[24:24+2048].split(b'\x00')[0].decode(errors='replace')
        print('vendor_boot v%d page=%d hdr=%d' % (hv,pg,hs))
        print('cmdline=%r' % cmd[:300])
        off=hs
        ks=u32(d,2096); rs=u32(d,2100)
        print('vendor ramdisk size=%d dtb size=%d' % (rs, u32(d,2104) if hv>=3 else 0))
        if hv>=3:
            ds=u32(d,2104); da=u32(d,2108)
            print('dtb_size=%d dtb_addr=0x%x' % (ds,da))
            rdoff=off; ramd=d[rdoff:rdoff+rs]; rdoff+=cl(rs,pg)
            dtb=d[rdoff:rdoff+ds]
            open(path+'.dtb','wb').write(dtb)
            open(path+'.ramdisk','wb').write(ramd)
            print('dtb magic=%s len=%d' % (dtb[:4].hex(), len(dtb)))
parse_boot(r'D:\本地项目-01\_twrp\Image\boot_a.img','boot_a')
parse_boot(r'D:\本地项目-01\_twrp\Image\vendor_boot_a.img','vendor_boot_a')