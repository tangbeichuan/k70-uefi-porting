#!/usr/bin/env python3
"""verify152.py -- offline verification for keys152 (minimal Menu) and
keys153 (keys149 FD repacked verbatim).

expectations:
  keys152: modules 89, SEC/PEI FFS sha cfcfca5e..., diff vs keys149 = VermeerMenuDxe only
          (size smaller than keys150's 20054), UTF-16 '[MENU152]' present, '[MENU150]' absent
  keys153: FD byte-identical to keys149, img byte-identical to Mu-vermeer-keys149.img
"""
import hashlib, struct, sys, uuid, lzma, zlib

Q = "/mnt/d/本地项目-01/_k70port_extract/qemu-fw"
O = "/mnt/d/本地项目-01/K70-UEFI-build"
LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
MENU_GUID = "4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"

def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u32(b,o): return struct.unpack_from("<I",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
def gstr(b,o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))
def sha(b): return hashlib.sha256(b).hexdigest()

def ffs_of_fd(path):
    fd = open(path,'rb').read()
    hdr = fd.find(b"_FVH", 0, 0x1000); base = hdr - 0x28
    fst = base + u16(fd, base+0x30); out = []; off = fst
    while off + 0x18 <= base + u64(fd, base+0x20):
        ft = fd[off+0x12]
        sz = fd[off+0x14] | (fd[off+0x15]<<8) | (fd[off+0x16]<<16)
        if sz < 0x18 or ft == 0xFF: break
        out.append(dict(off=off, size=sz, type=ft, guid=gstr(fd,off), body=fd[off+0x18:off+sz]))
        off = (off + sz + 7) & ~7
    return fd, out

def fvmain_modules(path):
    fd, ffs = ffs_of_fd(path)
    mods = {}
    for e in ffs:
        body = e["body"]; so = 0
        while so + 4 <= len(body):
            sz = body[so] | (body[so+1]<<8) | (body[so+2]<<16); st = body[so+3]
            if sz < 4: break
            if st == 0x02 and sz >= 24 and gstr(body, so+4) == LZMA_GUID:
                doff = so + u16(body, so+0x14)
                inner = lzma.decompress(body[doff:so+sz], format=lzma.FORMAT_ALONE)
                off = 0x50
                while off + 0x18 <= len(inner):
                    ft = inner[off+0x12]
                    z = inner[off+0x14] | (inner[off+0x15]<<8) | (inner[off+0x16]<<16)
                    if z < 0x18 or ft == 0xFF: break
                    if ft not in (0x0B,0xF0):
                        mods[gstr(inner,off)] = (hashlib.sha256(inner[off+0x18:off+z]).hexdigest()[:16], inner[off+0x18:off+z])
                    off = (off + z + 7) & ~7
            so = (so + sz + 3) & ~3
    return mods

def sec_ffs_sha(path):
    for e in ffs_of_fd(path)[1]:
        if e["type"] == 0x03:
            return sha(e["body"])[:16]

def bootimg(path):
    b = open(path,'rb').read()
    ks = u32(b,8); ps = u32(b,0x24) or 0x800
    p = b[ps:ps+ks]
    d = zlib.decompressobj(31); dec = d.decompress(p) + d.flush()
    return dict(raw=b, ks=ks, dec=dec, shim=dec[:192], fd=dec[192:], dtb=p[len(p)-len(d.unused_data):])

def main():
    ref_fd = Q + "/SILICIUM_UEFI-keys149.fd"
    ref = fvmain_modules(ref_fd)
    ref_sec = sec_ffs_sha(ref_fd)
    ref_img = bootimg(O + "/Mu-vermeer-keys149.img")
    print("keys149: modules %d, SEC/PEI sha %s, fd sha %s" % (len(ref), ref_sec, sha(open(ref_fd,'rb').read())[:16]))
    print("keys149 img sha %s size %d" % (sha(ref_img["raw"]), len(ref_img["raw"])))

    for tag in ("keys152", "keys153"):
        fd = Q + "/SILICIUM_UEFI-%s.fd" % tag
        img = O + "/Mu-vermeer-%s.img" % tag
        print("=" * 74)
        try:
            mods = fvmain_modules(fd)
            bi = bootimg(img)
        except FileNotFoundError as ex:
            print(tag, "MISSING", ex); continue
        fdsha = sha(open(fd,'rb').read())
        print("%s: modules %d SEC/PEI sha %s fd sha256 %s" % (tag, len(mods), sec_ffs_sha(fd), fdsha))
        print("  img sha256 %s size %d" % (sha(bi["raw"]), len(bi["raw"])))
        print("  kernel_size %d dec %d shim %d fd_in_img %d dtb %d" % (bi["ks"], len(bi["dec"]), len(bi["shim"]), len(bi["fd"]), len(bi["dtb"])))
        print("  fd_in_img == fd file:", bi["fd"] == open(fd,'rb').read())
        print("  dtb identical to keys149:", bi["dtb"] == ref_img["dtb"])
        only = sorted(set(mods)-set(ref)); gone = sorted(set(ref)-set(mods))
        changed = [g for g in set(mods)&set(ref) if mods[g][0] != ref[g][0]]
        print("  modules only here: %d, missing: %d, changed: %d" % (len(only), len(gone), len(changed)))
        for g in changed[:10]:
            nm = "VermeerMenuDxe" if g == MENU_GUID else g
            print("    changed %-28s size %d (keys149 %d)" % (nm, len(mods[g][1]), len(ref[g][1])))
        if tag == "keys152":
            body = mods.get(MENU_GUID, (None, b""))[1]
            for m in ("[MENU152]", "[USB152]", "[USB150]", "[MENU150]"):
                print("    menu body contains %-10s %s" % (m, m.encode() in body))
            print("    menu body has CpuDeadLoop() string: %s" % (b"CpuDeadLoop" in body))
        if tag == "keys153":
            print("  FD byte-identical to keys149:", open(fd,'rb').read() == open(ref_fd,'rb').read())
            print("  img byte-identical to keys149 img:", bi["raw"] == ref_img["raw"])
    # copies
    print("=" * 74)
    for c, tag in (("K70-keys152-MINIMAL-MENU.img", "keys152"), ("K70-keys153-REPACK-BASELINE.img", "keys153")):
        try:
            a = sha(open(O+"/"+c,'rb').read()); b = sha(open(O+"/Mu-vermeer-%s.img" % tag,'rb').read())
            print("%-34s copy sha match: %s" % (c, a == b))
        except FileNotFoundError:
            print(c, "missing")

if __name__ == "__main__":
    main()
