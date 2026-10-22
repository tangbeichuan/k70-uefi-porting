#!/usr/bin/env python3
"""k151_cmp.py -- compare two FDs module-by-module (handles LZMA FV sections).
usage: k151_cmp.py <fdA> <fdB>
"""
import lzma, struct, sys, uuid, hashlib

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"

def u16(b, o): return struct.unpack_from("<H", b, o)[0]
def u64(b, o): return struct.unpack_from("<Q", b, o)[0]
def gstr(b, o): return str(uuid.UUID(bytes_le=bytes(b[o:o+16])))

def sections(body):
    out, off = [], 0
    while off + 4 <= len(body):
        size = body[off] | (body[off+1] << 8) | (body[off+2] << 16)
        stype = body[off+3]
        if size < 4: break
        doff, sguid = off + 4, None
        if stype == 0x02 and size >= 24:
            sguid = gstr(body, off+4)
            doff = off + u16(body, off+0x14)
        out.append((stype, body[doff:off+size], sguid))
        off = (off + size + 3) & ~3
    return out

def walk(buf, mods, label="FD"):
    hdr = buf.find(b"_FVH", 0, 0x1000)
    if hdr < 0: return
    base = hdr - 0x28
    fv_len = u64(buf, base + 0x20)
    off = base + u16(buf, base + 0x30)
    end = min(len(buf), base + fv_len)
    while off + 0x18 <= end:
        ftype = buf[off+0x12]
        size = buf[off+0x14] | (buf[off+0x15] << 8) | (buf[off+0x16] << 16)
        if size < 0x18 or ftype == 0xFF: break
        guid = gstr(buf, off)
        body = buf[off+0x18: off+size]
        ui = None
        for stype, sdata, sguid in sections(body):
            if stype == 0x15:
                ui = sdata.decode("utf-16-le", "ignore").rstrip("\x00")
            elif stype == 0x02 and sguid == LZMA_GUID:
                inner = lzma.decompress(sdata, format=lzma.FORMAT_ALONE)
                walk(inner, mods, label + ">LZMA")
            elif stype == 0x17:
                walk(sdata, mods, label + ">FV_IMAGE")
        if ftype not in (0x0B, 0xF0):
            mods.append(dict(guid=guid, name=(ui or guid), body=body, size=size, label=label))
        off = (off + size + 7) & ~7

def load(path):
    fd = open(path, "rb").read()
    mods = []
    walk(fd, mods)
    return fd, mods

def main(a, b):
    fa, ma = load(a)
    fb, mb = load(b)
    print("A:", a, len(fa), "B; modules:", len(ma))
    print("B:", b, len(fb), "B; modules:", len(mb))
    ha = {(m["guid"].lower()): (m["name"], hashlib.sha256(m["body"]).hexdigest()[:16], m["label"], m["size"]) for m in ma}
    hb = {(m["guid"].lower()): (m["name"], hashlib.sha256(m["body"]).hexdigest()[:16], m["label"], m["size"]) for m in mb}
    onlya = sorted(set(ha) - set(hb)); onlyb = sorted(set(hb) - set(ha))
    changed = []
    for g in sorted(set(ha) & set(hb)):
        if ha[g][1] != hb[g][1]:
            changed.append(g)
    print("only in A:", [(ha[g][0], ha[g][3]) for g in onlya])
    print("only in B:", [(hb[g][0], hb[g][3]) for g in onlyb])
    print("changed:", len(changed))
    for g in changed:
        print("  %-28s A=%s/%d  B=%s/%d" % (ha[g][0], ha[g][1], ha[g][3], hb[g][1], hb[g][3]))
    # where do labels live
    lab = {}
    for g in ha:
        lab[ha[g][2]] = lab.get(ha[g][2], 0) + 1
    print("labels:", lab)
    print("bytes differ:", sum(1 for x, y in zip(fa, fb) if x != y), "of", min(len(fa), len(fb)))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
