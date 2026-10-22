#!/usr/bin/env python3
"""verify164.py -- offline verification of keys164 vs keys161.

keys164 = keys161 (minimal EP0 gadget, no CSFTRST) + Menu: GOP screen clear,
short [164] lines, RAW event trace (<=16, incl. dep evt raw), DEPCMD trace,
8 s / 16 events then "[164] done: ..." + CpuDeadLoop().

Expectations:
  * SEC/PEI identical to keys161;
  * inner FVMAIN: 0 added / 0 removed / exactly ONE changed module (VermeerMenuDxe);
  * Menu PE: [164] markers, CpuDeadLoop, EP0 arm strings (DALEPENA etc.),
    no QSCRATCH (0x0A6F8800), no GCC (0x0010F004), no CSFTRST pulse;
  * container: gzip(shim+FD) + trailing DTB identical to keys149/161 DTB.

Usage: python3 verify164.py [tag]      (default keys164, baseline keys161)
"""
import hashlib
import lzma
import pathlib
import struct
import subprocess
import sys
import uuid
import zlib

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
TAG = sys.argv[1] if len(sys.argv) > 1 else "keys164"
BASE = sys.argv[2] if len(sys.argv) > 2 else "keys161"
TOOLS = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract")
OUT = pathlib.Path("/mnt/d/本地项目-01/K70-UEFI-build")
FD = TOOLS / "qemu-fw" / f"SILICIUM_UEFI-{TAG}.fd"
FD_BASE = TOOLS / "qemu-fw" / f"SILICIUM_UEFI-{BASE}.fd"
IMG = OUT / f"Mu-vermeer-{TAG}.img"
MENU_GUID = "4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"


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
        out.append((stype, body[doff:off + size], sguid))
        off = (off + size + 3) & ~3
    return out


def fv_header(buf):
    hdr = buf.find(b"_FVH", 0, 0x1000)
    if hdr < 0:
        return None
    base = hdr - 0x28
    return dict(base=base, len=u64(buf, base + 0x20), hdrlen=u16(buf, base + 0x30),
                fst=base + u16(buf, base + 0x30))


def ffs_entries(buf):
    h = fv_header(buf)
    out = []
    if not h:
        return out
    off, end = h["fst"], min(len(buf), h["base"] + h["len"])
    while off + 0x18 <= end:
        ftype = buf[off + 0x12]
        size = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        if size < 0x18 or ftype == 0xFF:
            break
        out.append(dict(off=off, size=size, type=ftype, guid=gstr(buf, off),
                        body=buf[off + 0x18:off + size]))
        off = (off + size + 7) & ~7
    return out


def inner(fdbytes):
    for e in ffs_entries(fdbytes):
        if e["type"] == 0x0B:
            for stype, sdata, sguid in sections(e["body"]):
                if stype == 0x02 and sguid == LZMA_GUID:
                    return lzma.decompress(sdata, format=lzma.FORMAT_ALONE)
    return None


def main():
    fb, bb = FD.read_bytes(), FD_BASE.read_bytes()
    print(f"FD {TAG}: {len(fb)} B sha {sha(fb)}")
    print(f"FD {BASE}: {len(bb)} B sha {sha(bb)}")

    fa, ba = ffs_entries(fb), ffs_entries(bb)
    print(f"\nouter FFS: {TAG}={len(fa)} {BASE}={len(ba)}")
    for a, b in zip(fa, ba):
        print(f"  @0x{a['off']:06x} type={a['type']:#04x} guid={a['guid']} "
              f"size={a['size']}/{b['size']} sha={'SAME' if sha(a['body']) == sha(b['body']) else 'DIFF'}")

    sec_new = next(e for e in fa if e["type"] == 0x03)["body"]
    sec_old = next(e for e in ba if e["type"] == 0x03)["body"]
    print(f"\nSEC/PEI: {TAG}={len(sec_new)} sha {sha(sec_new)}")
    print(f"         {BASE}={len(sec_old)} sha {sha(sec_old)} identical={sha(sec_new) == sha(sec_old)}")

    inn_new, inn_old = inner(fb), inner(bb)
    nm = {e["guid"]: e["body"] for e in ffs_entries(inn_new)}
    om = {e["guid"]: e["body"] for e in ffs_entries(inn_old)}
    added = sorted(set(nm) - set(om))
    removed = sorted(set(om) - set(nm))
    changed = [(g, len(om[g]), len(nm[g])) for g in sorted(set(nm) & set(om)) if sha(nm[g]) != sha(om[g])]
    print(f"\ninner FVMAIN: {TAG}={len(inn_new)} B {BASE}={len(inn_old)} B")
    print(f"modules: {TAG}={len(nm)} {BASE}={len(om)} added={len(added)} removed={len(removed)} changed={len(changed)}")
    for g, a, b in changed:
        print(f"  CHANGED {g}: {a} -> {b} B")
    print(f"  EXPECT: exactly 1 changed = {MENU_GUID} (VermeerMenuDxe)")

    if IMG.exists():
        img = IMG.read_bytes()
        print(f"\nimg {IMG.name}: {len(img)} B sha {sha(img)}")
        page = u32(img, 36)
        ksz = u32(img, 8)
        do = zlib.decompressobj(31)
        dec = do.decompress(img[page:page + ksz])
        rest = do.unused_data
        print(f"  page={page} kernel={ksz} gzip-inner={len(dec)} B tail={len(rest)} B shim={len(dec) - len(fb)} B")
        print(f"  fd_in_img==FD: {dec[-len(fb):] == fb}")
        i = rest.find(b"\xd0\x0d\xfe\xed")
        print(f"  DTB {len(rest) - i} B sha {sha(rest[i:]) if i >= 0 else '-'}")
    else:
        print(f"\nimg MISSING: {IMG}")

    efis = sorted(pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB").rglob("VermeerMenuDxe.efi"))
    if efis:
        raw = efis[0].read_bytes()
        suf = TAG.replace("keys", "")
        print(f"\nMenu EFI: {efis[0]} {len(raw)} B sha {sha(raw)}")
        for m in (f"MENU{suf}", f"[{suf}] evt raw=", f"[{suf}] dep evt raw=", f"[{suf}] poll",
                  f"[{suf}] regs:", f"[{suf}] done: evts=", f"[{suf}] dep n=",
                  f"[{suf}] replug: pull-up off", f"[{suf}] replug: pull-up on",
                  "K70 UEFI DEBUG", "0x0A6F8800", "CpuDeadLoop"):
            print(f"  ascii {m}: {raw.count(m.encode())}  utf16 {m}: {raw.count(m.encode('utf-16-le'))}")
        dis = subprocess.run(["llvm-objdump", "-d", str(efis[0])], capture_output=True, text=True).stdout
        dep = [ln for ln in dis.splitlines() if any(k in ln for k in ("#0xc800", "#0xc804", "#0xc808", "#0xc80c", "#0xc81c", "#0xc720"))]
        gcc = [ln for ln in dis.splitlines() if "#0xf004" in ln or "#0x10f004" in ln]
        dead = [ln for ln in dis.splitlines() if "b\t0x" in ln]
        print(f"  disasm DEPCMD/DALEPENA immediate lines: {len(dep)}")
        for ln in dep[:14]:
            print("    ", ln.strip())
        print(f"  disasm GCC 0x0F004 lines (expect 0): {len(gcc)}")
        selfbr = 0
        for ln in dis.splitlines():
            parts = ln.split()
            if len(parts) >= 3 and parts[1].rstrip(":") and parts[2] == "b" and len(parts) > 3:
                try:
                    addr = int(parts[0].rstrip(":"), 16)
                    tgt = int(parts[3], 16)
                    if tgt == addr:
                        selfbr += 1
                except Exception:
                    pass
        print(f"  disasm self-branch (CpuDeadLoop) lines: {selfbr}")
    else:
        print("\nMenu EFI not found")

    ok = (len(added) == 0 and len(removed) == 0 and len(changed) == 1)
    print("\nRESULT:", "PASS" if ok else "CHECK")


if __name__ == "__main__":
    main()
