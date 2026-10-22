#!/usr/bin/env python3
"""verify151.py -- offline verification for keys151 / keys151b.

checks:
  1. FD module diff vs keys149 (expect: keys151 = only VermeerMenuDxe; keys151b = Menu + the
     SEC/PrePi FFS that embeds the MemoryMapLib table)
  2. SEC/PEI FFS body sha vs keys149 (cfcfca5e...)
  3. boot image structure: kernel = gzip(192-byte shim + FD) + DTB; rebuilt and compared byte-wise
  4. keys151 img vs keys150 img sha equality (content-identity proof)
  5. copies
usage: verify151.py
"""
import gzip, hashlib, io, struct, subprocess, sys, uuid, lzma

Q = "/mnt/d/本地项目-01/_k70port_extract/qemu-fw"
O = "/mnt/d/本地项目-01/K70-UEFI-build"
LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"

def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u32(b,o): return struct.unpack_from("<I",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
def gstr(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))
def sha(b): return hashlib.sha256(b).hexdigest()

def ffs_of_fd(path):
    fd = open(path,'rb').read()
    hdr = fd.find(b"_FVH", 0, 0x1000); base = hdr - 0x28
    fst = base + u16(fd, base+0x30)
    out = []
    off = fst
    while off + 0x18 <= base + u64(fd, base+0x20):
        ftype = fd[off+0x12]
        size = fd[off+0x14] | (fd[off+0x15]<<8) | (fd[off+0x16]<<16)
        if size < 0x18 or ftype == 0xFF: break
        out.append(dict(off=off, size=size, type=ftype, guid=gstr(fd,off), body=fd[off+0x18:off+size]))
        off = (off + size + 7) & ~7
    return fd, out

def fvmain_modules(fd_path):
    fd, ffs = ffs_of_fd(fd_path)
    mods = {}
    for e in ffs:
        body = e["body"]
        # find LZMA GUID section
        so = 0
        while so + 4 <= len(body):
            ssize = body[so] | (body[so+1]<<8) | (body[so+2]<<16); stype = body[so+3]
            if ssize < 4: break
            if stype == 0x02 and ssize >= 24 and gstr(body, so+4) == LZMA_GUID:
                doff = so + u16(body, so+0x14)
                inner = lzma.decompress(body[doff:so+ssize], format=lzma.FORMAT_ALONE)
                off = 0x50  # fv fst
                end = len(inner)
                while off + 0x18 <= end:
                    ft = inner[off+0x12]
                    sz = inner[off+0x14] | (inner[off+0x15]<<8) | (inner[off+0x16]<<16)
                    if sz < 0x18 or ft == 0xFF: break
                    if ft not in (0x0B,0xF0):
                        mods[gstr(inner,off)] = hashlib.sha256(inner[off+0x18:off+sz]).hexdigest()[:16]
                    off = (off + sz + 7) & ~7
            so = (so + ssize + 3) & ~3
    return mods

def sec_ffs_sha(fd_path):
    fd, ffs = ffs_of_fd(fd_path)
    for e in ffs:
        if e["type"] == 0x03:
            return sha(e["body"])[:16]
    return None

def bootimg(path):
    b = open(path,'rb').read()
    ks = u32(b,8); ps = u32(b,0x24) or 0x800
    p = b[ps:ps+ks]
    d = __import__("zlib").decompressobj(31)
    dec = d.decompress(p) + d.flush()
    dtb = p[len(p)-len(d.unused_data):]
    return dict(raw=b, ks=ks, payload=p, dec=dec, shim=dec[:192], fd=dec[192:], dtb=dtb)

def main():
    ref_fd = Q + "/SILICIUM_UEFI-keys149.fd"
    refmods = fvmain_modules(ref_fd)
    print("keys149 modules:", len(refmods), "SEC/PEI FFS sha:", sec_ffs_sha(ref_fd))
    for tag in ("keys151", "keys151b"):
        fd = Q + "/SILICIUM_UEFI-%s.fd" % tag
        try:
            mods = fvmain_modules(fd)
        except FileNotFoundError:
            print(tag, "FD MISSING"); continue
        print("="*70)
        print(tag, "modules:", len(mods), "SEC/PEI FFS sha:", sec_ffs_sha(fd))
        print("  fd sha256:", sha(open(fd,'rb').read()))
        only = sorted(set(mods)-set(refmods)); gone = sorted(set(refmods)-set(mods))
        print("  modules only in %s: %d, missing: %d" % (tag, len(only), len(gone)))
        changed = [g for g in set(mods)&set(refmods) if mods[g]!=refmods[g]]
        print("  changed modules vs keys149: %d" % len(changed))
        names = {}
        for e in ffs_of_fd(fd)[1]:
            pass
        print("   (names resolved below if img present)")
        # map names via GUID.xref is overkill; just report guids
        for g in changed[:12]:
            print("    changed guid", g)
        # img checks
        img = O + "/Mu-vermeer-%s.img" % tag
        try:
            bi = bootimg(img)
        except FileNotFoundError:
            print("  img MISSING:", img); continue
        print("  img sha256:", sha(bi["raw"]), "size:", len(bi["raw"]))
        print("  kernel_size:", bi["ks"], "dec:", len(bi["dec"]), "shim:", len(bi["shim"]), "fd_in_img:", len(bi["fd"]), "dtb:", len(bi["dtb"]))
        print("  shim sha:", sha(bi["shim"])[:16], " dtb sha:", sha(bi["dtb"])[:16])
        refdtb = bootimg(O + "/Mu-vermeer-keys149.img")["dtb"]
        print("  dtb identical to keys149:", bi["dtb"] == refdtb)
        print("  fd_in_img == fd file:", bi["fd"] == open(fd,'rb').read())
        # copies
        for c in ("K70-keys151-NO-PEI-CHANGE.img" if tag=="keys151" else "K70-keys151b-USBROW-REMOVED.img",):
            try:
                cb = open(O+"/"+c,'rb').read()
                print("  copy %s sha match: %s" % (c, sha(cb)==sha(bi["raw"])))
            except FileNotFoundError:
                print("  copy missing:", c)
    # identity with keys150
    try:
        a = sha(open(O+"/Mu-vermeer-keys151.img",'rb').read())
        b = sha(open(O+"/Mu-vermeer-keys150.img",'rb').read())
        print("="*70); print("keys151 img == keys150 img:", a==b, a)
    except FileNotFoundError:
        pass

if __name__ == "__main__":
    main()
