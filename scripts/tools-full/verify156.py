#!/usr/bin/env python3
"""verify156.py -- offline verification for keys156 (keys154 + [USB156] alive markers).

Expected vs keys154 baseline:
  * FD modules: same count, only VermeerMenuDxe changed
  * SEC/PEI FFS unchanged (sha = keys154's cfcfca5e..., no GCC row)
  * Menu: USB156 x2, MENU154/USB154 kept, no GCC immediate, has Stall(3000000)
    disassembly (movz/movk 0x2dc6c0) right after the bring-up block
  * container: gzip(shim+FD) == FD file; trailing DTB == keys154's
usage: verify156.py [keys156]
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
BASE_FD = FW / "SILICIUM_UEFI-keys154.fd"
BASE_IMG = OUT / "Mu-vermeer-keys154.img"
LZ = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
MENU = "4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"


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


def parse_fv(dec):
    out, io = {}, 0x50
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
                cands = [0x48, 0x50, 0x78, u16(dec, dec.find(b"_FVH", 0, 0x1000) - 0x28 + 0x30)]
                best = {}
                for c in cands:
                    try:
                        m = parse_fv_c(dec, c)
                    except Exception:
                        m = {}
                    if len(m) > len(best):
                        best = m
                return best
            so = (so + ssz + 3) & ~3
        off = (off + sz + 7) & ~7
    return {}


def parse_fv_c(dec, first):
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


def main(tag="keys156"):
    fd = FW / f"SILICIUM_UEFI-{tag}.fd"
    img = OUT / f"Mu-vermeer-{tag}.img"
    fb, ft = BASE_FD.read_bytes(), fd.read_bytes()
    mb, mt = fvmain_modules(fb), fvmain_modules(ft)

    print(f"=== {tag} vs keys154 module diff ===")
    print(f"  modules base={len(mb)} new={len(mt)} added={len(set(mt) - set(mb))} removed={len(set(mb) - set(mt))}")
    changed = [g for g in sorted(set(mb) & set(mt)) if mb[g] != mt[g]]
    print(f"  changed={len(changed)}")
    for g in changed:
        print(f"    {g}: {mb[g][0]}->{mt[g][0]} {'<-- MENU' if g == MENU else ''}")
    print(f"  FD sha256={sha(ft)}")

    sb, st = sec_ffs(fb), sec_ffs(ft)
    print(f"=== SEC/PEI ===\n  keys154 size={len(sb)} sha={sha(sb)}\n  {tag} size={len(st)} sha={sha(st)} same={sb == st}")
    for n in (b"GCC\x00", b"USB\x00"):
        print(f"  region {n!r}: {st.count(n)}")

    rb, db, dtb, _ = container(BASE_IMG)
    rt, dt, dtt, ks = container(img)
    print("=== container ===")
    print(f"  img size={len(rt)} kernel_size={ks} decompressed={len(dt)}")
    print(f"  shim 0xC0 + fd {len(dt) - 0xC0}; fd_in_img == FD file: {dt[0xC0:] == ft}")
    print(f"  trailing DTB len={len(dtt)} sha={sha(dtt)} same_as_keys154={dtt == dtb}")
    print(f"  img sha256={sha(rt)}")

    # menu efi from build tree
    base = pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB")
    cands = list(base.rglob("VermeerMenuDxe.efi"))
    if not cands:
        print("=== menu EFI not found ==="); return
    med = cands[0]
    raw = med.read_bytes()
    print(f"=== Menu {med} size={len(raw)} ===")
    for m in ("MENU154", "USB154", "USB156", "Usb154Run"):
        print(f"  utf16 {m}: {raw.count(m.encode('utf-16-le'))}")
    asm = subprocess.run(["llvm-objdump", "-d", str(med)], capture_output=True, text=True).stdout.lines if False else subprocess.run(["llvm-objdump", "-d", str(med)], capture_output=True, text=True).stdout
    lines = asm.splitlines()
    gcc = [l for l in lines if "#0xf004" in l or "#0xf010" in l or "#0x100000" in l]
    print(f"  GCC-related immediates in Menu: {len(gcc)} (expect 0)")
    stall = [l for l in lines if "#0x2dc6c0" in l or "#0xc6c0" in l]
    print(f"  Stall(3000000) materialisation lines: {len(stall)} (expect >=1)")
    for l in stall[:6]:
        print("   ", l.strip())
    # context around the stall
    for i, l in enumerate(lines):
        if "#0xc6c0" in l:
            print("  --- context ---")
            for x in lines[max(0, i - 6):i + 8]:
                print("   ", x.strip())
            break


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "keys156")
