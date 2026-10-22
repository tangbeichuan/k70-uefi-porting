p = r'D:\本地项目-01\_twrp\ramdisk.img'
d = open(p,'rb').read()
print('len', len(d))
print('head32', d[:32].hex())
print('tail32', d[-32:].hex())
# 头尾各找 magic
for m,n in ((b'\x1f\x8b\x08','gzip'),(b'\x04\x22\x4d\x18','lz4'),(b'\x28\xb5\x2f\xfd','zstd'),(b'\xfd7zXZ','xz'),(b'BZh','bzip2'),(b'070701','cpio_newc')):
    print(n, d.find(m), d.rfind(m))