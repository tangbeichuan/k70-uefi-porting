#!/usr/bin/env python3
"""verify161.py -- offline verification of keys161 vs keys159.

Expectations:
  * outer FFS: SEC/PEI body identical (no GCC row, keys149 PEI sha);
  * inner FVMAIN: 0 added / 0 removed / exactly ONE changed module
    (VermeerMenuDxe = 4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90);
  * container: gzip(shim+FD) + trailing DTB identical to previous versions;
  * Menu PE: strings [MENU161]/[USB161]/K70 UEFI DEBUG; no GCC constant;
    disasm shows DEPCMD writes to 0xC80C/0xC81C and GEVNT window
    (0xC400..0xC40C) plus DCTL(0xC704)/DEVTEN(0xC708) accesses.
Usage: python3 verify161.py [tag]     (default keys161, baseline keys159)
"""
import gzip
import hashlib
import lzma
import pathlib
import struct
import subprocess
import sys
import uuid
import zlib

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
TAG = sys.argv[1] if len(sys.argv) > 1 else "keys161"
BASE = "keys160"
TOOLS = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract")
OUT = pathlib.Path("/mnt/d/本地项目-01/K70-UEFI-build")
FD = TOOLS / "qemu-fw" / f"SILICIUM_UEFI-{TAG}.fd"
FD_BASE = TOOLS / "qemu-fw" / f"SILICIUM_UEFI-{BASE}.fd"
IMG = OUT / f"Mu-vermeer-{TAG}.img"


def u16(b, o): return struct.unpack_from("<H", b, o)[0]
def u32(b, o): return struct.unpack_from("<I", b, o)[0]
def u64(b, o): return struct.unpack_from("<Q", b, o)[0]
def sha(b): return hashlib.sha256(b).hexdigest()
def gstr(b, o): return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))


def sections(body):
    out, off = [], 0
    while off + 4 <= len(body):
        size = body[off] | (body[off + 1] << 8) | (body[off + 2] << 16)
        stype = body[off + 3]
        if size < 4:
            break
        doff, sguid = off + 4, None
        if stype == 0x02 and size >= 24:
            sguid = gstr(body, off + 4)
            doff = off + u16(body, off + 0x14)
        out.append((stype, body[doff:off + size], sguid, off, size))
        off = (off + size + 3) & ~3
    return out


def fv_header(buf, at=0):
    hdr = buf.find(b"_FVH", at, at + 0x1000)
    if hdr < 0:
        return None
    base = hdr - 0x28
    return dict(base=base, len=u64(buf, base + 0x20), hdrlen=u16(buf, base + 0x30),
                fst=base + u16(buf, base + 0x30), ext=u32(buf, base + 0x34))


def ffs_entries(buf):
    h = fv_header(buf)
    out = []
    if not h:
        return out, None
    off, end = h["fst"], min(len(buf), h["base"] + h["len"])
    while off + 0x18 <= end:
        ftype = buf[off + 0x12]
        size = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        if size < 0x18 or ftype == 0xFF:
            break
        out.append(dict(off=off, size=size, type=ftype, guid=gstr(buf, off),
                        body=buf[off + 0x18:off + size]))
        off = (off + size + 7) & ~7
    return out, h


def inner_modules(fvbytes):
    return {e["guid"]: e["body"] for e in ffs_entries(fvbytes)[0]}


def main():
    fb, bb = FD.read_bytes(), FD_BASE.read_bytes()
    print(f"FD {TAG}: {len(fb)} B sha {sha(fb)}")
    print(f"FD {BASE}: {len(bb)} B sha {sha(bb)}")

    fa, _ = ffs_entries(fb)
    ba, _ = ffs_entries(bb)
    print(f"\nouter FFS: {TAG}={len(fa)} {BASE}={len(ba)}")
    for a, b in zip(fa, ba):
        print(f"  @0x{a['off']:06x} type={a['type']:#04x} guid={a['guid']} "
              f"size={a['size']}/{b['size']} sha={'SAME' if sha(a['body'])==sha(b['body']) else 'DIFF'}")

    sec_new = next(e for e in fa if e["type"] == 0x03)["body"]
    sec_old = next(e for e in ba if e["type"] == 0x03)["body"]
    print(f"\nSEC/PEI: {TAG}={len(sec_new)} sha {sha(sec_new)}")
    print(f"         {BASE}={len(sec_old)} sha {sha(sec_old)} identical={sha(sec_new)==sha(sec_old)}")
    for name in (b"GCC\0", b"USB\0"):
        print(f"  {name!r}: new={sec_new.count(name)} base={sec_old.count(name)}")

    def inner(fdbytes):
        for e in ffs_entries(fdbytes)[0]:
            if e["type"] == 0x0B:
                for stype, sdata, sguid, _, _ in sections(e["body"]):
                    if stype == 0x02 and sguid == LZMA_GUID:
                        return lzma.decompress(sdata, format=lzma.FORMAT_ALONE)
        return None

    inn_new, inn_old = inner(fb), inner(bb)
    print(f"\ninner FVMAIN: {TAG}={len(inn_new)} B {BASE}={len(inn_old)} B")
    nm, om = inner_modules(inn_new), inner_modules(inn_old)
    added = sorted(set(nm) - set(om))
    removed = sorted(set(om) - set(nm))
    changed = [(g, len(om[g]), len(nm[g])) for g in sorted(set(nm) & set(om)) if sha(nm[g]) != sha(om[g])]
    print(f"modules: {TAG}={len(nm)} {BASE}={len(om)} added={len(added)} removed={len(removed)} changed={len(changed)}")
    for g in added:
        print(f"  ADDED   {g} ({len(nm[g])} B)")
    for g in removed:
        print(f"  REMOVED {g} ({len(om[g])} B)")
    for g, a, b in changed:
        print(f"  CHANGED {g}: {a} -> {b} B")
    print("  EXPECT: exactly 1 changed = 4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90 (VermeerMenuDxe)")

    if IMG.exists():
        img = IMG.read_bytes()
        print(f"\nimg {IMG.name}: {len(img)} B sha {sha(img)}")
        page = u32(img, 36)
        ksz = u32(img, 8)
        do = zlib.decompressobj(31)
        dec = do.decompress(img[page:page + ksz])
        rest = do.unused_data
        print(f"  page={page} kernel={ksz} gzip-inner={len(dec)} B tail={len(rest)} B shim={len(dec) - len(fb)} B")
        print(f"  fd_in_img==FD: {dec[-(len(fb)):] == fb}")
        i = rest.find(b"\xd0\x0d\xfe\xed")
        print(f"  DTB {len(rest) - i} B sha {sha(rest[i:]) if i >= 0 else '-'}")
    else:
        print(f"\nimg MISSING: {IMG}")

    efis = sorted(pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB").rglob("VermeerMenuDxe.efi"))
    if efis:
        raw = efis[0].read_bytes()
        print(f"\nMenu EFI: {efis[0]} {len(raw)} B sha {sha(raw)}")
        for m in ("MENU161", "USB161", "K70 UEFI DEBUG", "Vermeer", "0x0010F004",
                  "poll: DCTL", "poll2:", "bringup done", "evt raw", "dep n="):
            print(f"  ascii {m}: {raw.count(m.encode())}  utf16 {m}: {raw.count(m.encode('utf-16-le'))}")
        dis = subprocess.run(["llvm-objdump", "-d", str(efis[0])], capture_output=True, text=True).stdout
        keys = ("#0xc80c", "#0xc81c", "#0xc800", "#0xc804", "#0xc808", "#0xc400", "#0xc404",
                "#0xc408", "#0xc40c", "#0xc704", "#0xc708", "#0xc720", "#0xc700", "#0xc200")
        hits = [ln for ln in dis.splitlines() if any(k in ln for k in keys)]
        print(f"  disasm lines touching DEPCMD/GEVNT/DCTL/DEVTEN: {len(hits)}")
        for ln in hits[:26]:
            print("   ", ln.strip())
    else:
        print("\nMenu EFI not found")

    ok = (len(added) == 0 and len(removed) == 0 and len(changed) == 1)
    print("\nRESULT:", "PASS" if ok else "CHECK")


if __name__ == "__main__":
    main()
