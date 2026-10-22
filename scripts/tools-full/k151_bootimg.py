#!/usr/bin/env python3
"""k151_bootimg.py -- decode Android-bootimg style Mu-vermeer-keys*.img and
compare payload structure of two images.
usage: k151_bootimg.py <imgA> <imgB> [...]
"""
import gzip, hashlib, io, struct, sys, zlib

def u32(b,o): return struct.unpack_from("<I",b,o)[0]

def decode(path, verbose=True):
    b = open(path,'rb').read()
    out = {}
    out['path']=path; out['size']=len(b)
    out['magic']=b[:8]
    for name,off in (('kernel_size',8),('kernel_addr',0xc),('ramdisk_size',0x10),
                     ('ramdisk_addr',0x14),('second_size',0x18),('second_addr',0x1c),
                     ('tags_addr',0x20),('page_size',0x24),('header_version',0x28),
                     ('os_version',0x2c)):
        out[name]=u32(b,off)
    out['name']=b[0x30:0x40].split(b'\x00')[0]
    out['cmdline']=b[0x40:0x240].split(b'\x00')[0]
    out['id']=b[0x240:0x260].hex()
    out['extra']=b[0x260:0x460].split(b'\x00')[0]
    if verbose:
        print("="*78)
        print(path, len(b), "B sha256", hashlib.sha256(b).hexdigest())
        for k in ('magic','kernel_size','kernel_addr','ramdisk_size','ramdisk_addr',
                  'second_size','second_addr','tags_addr','page_size','header_version','os_version','name','id'):
            v = out[k]
            print("  %-14s %s" % (k, v if not isinstance(v,int) else (hex(v), v)))
        print("  cmdline        %r" % out['cmdline'][:200])
        print("  extra          %r" % out['extra'][:200])
    # payload area: page aligned
    ps = out['page_size'] if out['page_size'] in (0x200,0x400,0x800,0x1000,0x2000,0x4000,0x8000) else 0x800
    k_off = ps
    out['payload_off']=k_off
    out['payload']=b[k_off:k_off+out['kernel_size']]
    return out

def probe_payload(o, verbose=True):
    p = o['payload']
    tag = None
    if p[:2] == b"\x1f\x8b": tag = "gzip"
    elif p[:4] == b"\xfd7zXZ\x00": tag = "xz"
    else: tag = "raw"
    if verbose: print("  payload: off=0x%x len=%d tagguess=%s head16=%s" % (o['payload_off'], len(p), tag, p[:16].hex()))
    data = p
    try:
        if tag == "gzip" or p[:2]==b"\x1f\x8b":
            d = zlib.decompressobj(31)
            data = d.decompress(p) + d.flush()
            if verbose:
                print("   gzip -> %d B sha=%s consumed=%d unused_tail=%d" %
                      (len(data), hashlib.sha256(data).hexdigest()[:16], len(p)-len(d.unused_data), len(d.unused_data)))
        elif p[:4]==b"\xfd7zXZ\x00":
            import lzma
            data = lzma.decompress(p)
            if verbose:
                print("   xz -> %d B sha=%s" % (len(data), hashlib.sha256(data).hexdigest()[:16]))
    except Exception as e:
        if verbose: print("   decompress failed:", e)
    o['dec'] = data
    if verbose:
        print("   deco _FVH@%s dec size=%d sha=%s" % ([hex(x) for x in [data.find(b'_FVH')][:1]], len(data), hashlib.sha256(data).hexdigest()[:16]))
        # look for known markers
        for pat in (b"MMU: enabled", b"Loading DxeCore", b"GSNPSID=", b"USB150", b"USB149"):
            print("     %-14s count=%d" % (pat.decode('latin1'), data.count(pat)))
    return data

def main(pa, pb):
    a = decode(pa); b = decode(pb)
    da = probe_payload(a); db = probe_payload(b)
    n=min(len(da),len(db)); diffs=[i for i in range(n) if da[i]!=db[i]]
    print("decoded payload differing bytes:", len(diffs), "first:", hex(diffs[0]) if diffs else None, "last:", hex(diffs[-1]) if diffs else None)
    print("decoded sizes:", len(da), len(db))

if __name__=="__main__":
    if len(sys.argv)==3: main(sys.argv[1],sys.argv[2])
    else:
        for p in sys.argv[1:]: probe_payload(decode(p))
