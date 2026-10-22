import lzma, struct, sys, glob, os

def find_fdt_in_fd(path):
    d = open(path, 'rb').read()
    res = {'path': path, 'size': len(d), 'raw_fdt': d.count(bytes.fromhex('d00dfeed')),
           'lzma_streams': 0, 'decomp_fdt': 0, 'has_ufs0': False}
    cands = []
    start = 0
    while True:
        i = d.find(b'\x5d\x00\x00', start)
        if i < 0:
            break
        cands.append(i)
        start = i + 1
        if len(cands) > 64:
            break
    for off in cands:
        try:
            dec = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE)
            out = dec.decompress(d[off:], max_length=64 * 1024 * 1024)
        except Exception:
            continue
        if len(out) < 1024:
            continue
        res['lzma_streams'] += 1
        n = out.count(bytes.fromhex('d00dfeed'))
        res['decomp_fdt'] += n
        if b'init_speed_params' in out:
            res['has_ufs0'] = True
        if n:
            res['first_fdt_size'] = struct.unpack('>I', out[out.find(bytes.fromhex('d00dfeed')) + 4:][:4])[0]
        res.setdefault('decomp_sizes', []).append(len(out))
        break
    return res

for p in sorted(glob.glob('/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys1[5-9].fd')):
    try:
        print(find_fdt_in_fd(p))
    except Exception as e:
        print(p, 'ERR', e)
