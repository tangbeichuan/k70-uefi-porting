#!/usr/bin/env python3
"""verify157.py -- offline verification for keys157.

keys157 = keys156 lineage with
  * VermeerDtbExtnDxe: early DWC3 device-mode bring-up ([USB157] early pre/run)
  * VermeerMenuDxe   : read-only resident monitor ([MENU157]/[USB157], key poll,
                       no DWC3/QSCRATCH/GCC writes, no CpuDeadLoop)

checks:
  * module diff vs keys156: exactly 2 changed (Menu + DtbExtn), 0 added/removed
  * SEC/PEI identical to keys156 (cfcfca5e..., no GCC row)
  * container: gzip(shim+FD)==FD file, trailing DTB unchanged
  * Menu EFI: MENU157/USB157 strings, ReadKeyStroke + Stall(100000) loop,
    no USB/GCC store instructions, no "CpuDeadLoop" text
  * DtbExtn EFI: "[USB157] early pre/run" strings present
usage: verify157.py [tag]
"""
import hashlib
import pathlib
import struct
import subprocess
import sys
import uuid
import zlib

FW = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/qemu-fw")
OUT = pathlib.Path("/mnt/d/本地项目-01/K70-UEFI-build")
BUILD = pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB")
BASE_TAG = "keys156"
MENU = "4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"
DTBEXTN = "5b21e7c4-3d18-4f6a-9a20-8c7e51fd42b9"
LZ = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"


def sha(b):
    return hashlib.sha256(b).hexdigest()


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def gs(b, o):
    return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))


def parse_fv(dec, first):
    out, io = {}, first
    while io + 0x18 <= len(dec):
        it = dec[io + 0x12]
        iz = dec[io + 0x14] | (dec[io + 0x15] << 8) | (dec[io + 0x16] << 16)
        if iz < 0x18 or it == 0xFF:
            break
        if it not in (0x0B, 0xF0):
            out[gs(dec, io)] = (iz, sha(dec[io:io + iz]))
        io = (io + iz + 7) & ~7
    return out


def fvmain_modules(buf):
    hdr = buf.find(b"_FVH", 0, 0x1000)
    base = hdr - 0x28
    off = base + u16(buf, base + 0x30)
    end = base + u64(buf, base + 0x20)
    while off + 0x18 <= end:
        ft = buf[off + 0x12]
        sz = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        if sz < 0x18 or ft == 0xFF:
            break
        body = buf[off + 0x18:off + sz]
        so = 0
        while so + 4 <= len(body):
            ssz = body[so] | (body[so + 1] << 8) | (body[so + 2] << 16)
            st = body[so + 3]
            if ssz < 4:
                break
            if st == 0x02 and gs(body, so + 4) == LZ:
                import lzma
                dec = lzma.decompress(body[so + u16(body, so + 0x14):so + ssz],
                                      format=lzma.FORMAT_ALONE)
                cands = [0x48, 0x50, 0x78,
                         u16(dec, dec.find(b"_FVH", 0, 0x1000) - 0x28 + 0x30)]
                best = {}
                for c in cands:
                    try:
                        m = parse_fv(dec, c)
                    except Exception:
                        m = {}
                    if len(m) > len(best):
                        best = m
                return best
            so = (so + ssz + 3) & ~3
        off = (off + sz + 7) & ~7
    return {}


def sec_ffs(buf):
    hdr = buf.find(b"_FVH", 0, 0x1000)
    base = hdr - 0x28
    off = base + u16(buf, base + 0x30)
    while off + 0x18 <= len(buf):
        ft = buf[off + 0x12]
        sz = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        if sz < 0x18 or ft == 0xFF:
            break
        if ft == 0x03:
            return buf[off + 0x18:off + sz]
        off = (off + sz + 7) & ~7
    return None


def container(img):
    raw = img.read_bytes()
    ks = u32(raw, 8)
    ps = u32(raw, 0x24) or 0x800
    d = zlib.decompressobj(31)
    dec = d.decompress(raw[ps:ps + ks]) + d.flush()
    return raw, dec, d.unused_data, ks


def asm_of(efi):
    return subprocess.run(["llvm-objdump", "-d", str(efi)],
                          capture_output=True, text=True).stdout.splitlines()


def main(tag="keys157"):
    fd = FW / f"SILICIUM_UEFI-{tag}.fd"
    img = OUT / f"Mu-vermeer-{tag}.img"
    fb, ft = (FW / f"SILICIUM_UEFI-{BASE_TAG}.fd").read_bytes(), fd.read_bytes()
    mb, mt = fvmain_modules(fb), fvmain_modules(ft)

    print(f"=== {tag} vs {BASE_TAG} module diff ===")
    print(f"  modules base={len(mb)} new={len(mt)} added={len(set(mt) - set(mb))} "
          f"removed={len(set(mb) - set(mt))}")
    changed = [g for g in sorted(set(mb) & set(mt)) if mb[g] != mt[g]]
    print(f"  changed={len(changed)} (expect 2: MENU + DTBEXTN)")
    for g in changed:
        note = " <-- MENU" if g == MENU else (" <-- DTBEXTN" if g == DTBEXTN else " <-- UNEXPECTED")
        print(f"    {g}: {mb[g][0]}->{mt[g][0]}{note}")

    sb, st = sec_ffs(fb), sec_ffs(ft)
    print(f"=== SEC/PEI ===\n  {BASE_TAG} size={len(sb)} sha={sha(sb)}"
          f"\n  {tag} size={len(st)} sha={sha(st)} same={sb == st}")

    rb, db, dtb, _ = container(OUT / f"Mu-vermeer-{BASE_TAG}.img")
    rt, dt, dtt, ks = container(img)
    print("=== container ===")
    print(f"  img size={len(rt)} kernel_size={ks}")
    print(f"  fd_in_img == FD file: {dt[0xC0:] == ft}")
    print(f"  trailing DTB {len(dtt)} B sha={sha(dtt)} same_as_{BASE_TAG}={dtt == dtb}")
    print(f"  img sha256={sha(rt)}")

    menu = next(BUILD.rglob("VermeerMenuDxe.efi"), None)
    dtx = next(BUILD.rglob("VermeerDtbExtnDxe.efi"), None)
    if menu is None or dtx is None:
        print("=== EFI artifacts not found ===")
        return
    for path, marks in ((menu, ("MENU157", "USB157", "UI157", "CpuDeadLoop")),
                        (dtx, ("USB157", "[VBUS]"))):
        raw = path.read_bytes()
        print(f"=== {path.name} {len(raw)} B ===")
        for m in marks:
            print(f"  ascii {m}: {raw.count(m.encode())}  utf16 {raw.count(m.encode('utf-16-le'))}")

    lines = asm_of(menu)
    gcc = [l for l in lines if "#0xf004" in l or "#0xf010" in l or "#0x100000" in l]
    print(f"  Menu GCC immediates: {len(gcc)} (expect 0)")
    stall = [l for l in lines if "#0x86a0" in l and "#0x1" in l]
    print(f"  Menu Stall(100000) movz/movk lines: {len(stall)}")
    # USB/QSCRATCH writes: any str whose address register was loaded from those windows
    usb_addr = [i for i, l in enumerate(lines) if "0xa600000" in l or "0xa6f8800" in l]
    writes = []
    for i in usb_addr:
        win = lines[i:i + 10]
        for l in win:
            if l.strip().startswith("str ") or "\tstr " in l:
                writes.append((lines[i].strip(), l.strip()))
                break
    print(f"  Menu USB/QSCRATCH store windows: {len(writes)} (expect 0)")
    for w in writes[:6]:
        print("    ", w)
    keys = [l for l in lines if "ReadKeyStroke" in l or "#0x1f" in l]
    print(f"  Menu ReadKeyStroke-ish lines: {len([l for l in lines if 'ldr' in l and '#0x18' in l])} (informational)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "keys157")
