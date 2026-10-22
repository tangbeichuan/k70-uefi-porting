import struct, sys, os, zlib, io
p = 'D:\\本地项目-01\\_twrp\\recovery_a.img'
d = open(p,'rb').read()
assert d[:8] == b'ANDROID!'
def u32(b, o): return struct.unpack_from('<I', b, o)[0]
k_size  = u32(d, 8)
k_addr  = u32(d, 12)
r_size  = u32(d, 16)
r_addr  = u32(d, 20)
s_size  = u32(d, 24)
s_addr  = u32(d, 28)
tags    = u32(d, 32)
page    = u32(d, 36)
hv      = u32(d, 40)
osver   = u32(d, 44)
name    = d[48:64].split(b'\x00')[0].decode()
cmd     = d[64:576].split(b'\x00')[0].decode()
hdrver  = u32(d, 1024+16) if len(d) > 1040 else 0
def cl(x, pg):
    return (x + pg - 1)//pg*pg if x else 0
print('header_version=%d  page=%d  kernel=%d  ramdisk=%d  second=%d' % (hv, page, k_size, r_size, s_size))
print('kernel_addr=0x%x ramdisk_addr=0x%x tags_addr=0x%x osver=0x%x' % (k_addr, r_addr, tags, osver))
print('name=%r' % name)
print('cmdline=%r' % cmd[:200])
off = page
kern = d[off:off+k_size]; off += cl(k_size, page)
rd   = d[off:off+r_size]; off += cl(r_size, page)
sec  = d[off:off+s_size]; off += cl(s_size, page)
print('ramdisk off=0x%x len=%d magic=%s' % (page+cl(k_size,page), len(rd), rd[:6]))
# recovery_dtbo (v1+) / dtb (v2+)
if hv >= 1:
    rh = u32(d, 1632); ro = u32(d, 1636); rs = u32(d, 1640)
    print('recovery_dtbo size=%d off=%d' % (rs, ro))
if hv >= 2:
    dtb_size = u32(d, 1648); dtb_addr = u32(d, 1652)
    print('dtb size=%d addr=0x%x' % (dtb_size, dtb_addr))
    hdr_off = 4096
    dtb = d[hdr_off:hdr_off+dtb_size] if dtb_size else b''
    open('D:\\本地项目-01\\_twrp\\recovery.dtb','wb').write(dtb)
    print('dtb magic=%s len=%d' % (dtb[:4].hex(), len(dtb)))
open('D:\\本地项目-01\\_twrp\\kernel.bin','wb').write(kern)
open('D:\\本地项目-01\\_twrp\\ramdisk.gz','wb').write(rd)
print('kernel magic=%s' % kern[:4].hex())
ck = kern.find(b'\x1f\x8b')
print('gzip inside kernel at', ck)