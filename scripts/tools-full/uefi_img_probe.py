import struct, sys
path = '/mnt/d/本地项目-01/_k70_pkg_1019/K70-UEFI-package/extracted/uefi_a.img'
d = open(path, 'rb').read()
print('file', path)
print('size', len(d))
magic = bytes.fromhex('d00dfeed')
print('FDT magic count', d.count(magic))
i = -1
while True:
    i = d.find(magic, i + 1)
    if i < 0:
        break
    tot = struct.unpack('>I', d[i + 4:i + 8])[0]
    print('   fdt at', hex(i), 'size', tot)
print('has init_speed_params:', b'init_speed_params' in d)
print('has qcom,ufs:', b'qcom,ufs' in d)
print('has kailua:', b'qcom,kailua' in d)
try:
    blob = open('/mnt/d/本地项目-01/_k70_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_10168.dtb', 'rb').read()
    print('kailua dtb size', len(blob), 'present in uefi_a.img:', blob in d, 'header-only present:', blob[:4096] in d)
except Exception as e:
    print('err', e)
