#!/usr/bin/env python3
"""verify154.py -- offline verification for keys154 (and keys152b).

Checks, against the known-good keys152 baseline:
  * FD module list: only VermeerMenuDxe changed (size/sha), 0 modules added/removed
  * SEC/PEI FFS body sha == cfcfca5efb6b80fe (same memory map as keys149/152)
  * inner FVMAIN length 0x5df000, no PEI bytes changed
  * boot container: gzip(shim192+FD) payload identical to FD file, trailing DTB
    identical to keys152's DTB
  * Menu EFI markers (UTF-16): MENU154 / USB154 for keys154, MENU152B for 152b
  * Menu disassembly: no `mov w8, #0xf004` + `movk w8, #0x10, lsl #16` (GCC read)

usage: verify154.py <tag>      e.g. verify154.py keys154 | verify154.py keys152b
"""
import gzip
import hashlib
import pathlib
import struct
import subprocess
import sys

TOOLS = pathlib.Path("/mnt/d/本地项目-01/_tools")
OUT = pathlib.Path("/mnt/d/本地项目-01/K70-UEFI-build")
FW = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/qemu-fw")
BASE_FD = FW / "SILICIUM_UEFI-keys152.fd"
BASE_IMG = OUT / "Mu-vermeer-keys152.img"

LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"


def sha(b):
    return hashlib.sha256(b).hexdigest()


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def gstr(b, o):
    import uuid
    return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))


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


def walk_fd(buf, label):
    """Return (modules dict guid->(name?,size,sha), sec_ffs_sha, fvmain_len)."""
    mods = {}
    sec_sha = None
    fvmain_len = None
    hdr = buf.find(b"_FVH", 0, 0x1000)
    base = hdr - 0x28
    fv_len = u64(buf, base + 0x20)
    off = base + u16(buf, base + 0x30)
    end = min(len(buf), base + fv_len)
    while off + 0x18 <= end:
        ftype = buf[off + 0x12]
        size = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        if size < 0x18 or ftype == 0xFF:
            break
        guid = gstr(buf, off)
        body = buf[off + 0x18: off + size]
        if ftype == 0x03:  # SECURITY_CORE (Sec/PrePi)
            sec_sha = sha(body)
        for stype, data, sguid in sections(body):
            if stype == 0x02 and sguid == LZMA_GUID:
                try:
                    import lzma
                    dec = lzma.decompress(data[0:])
                except Exception:
                    dec = None
                if dec is not None:
                    fvmain_len = len(dec)
                    # parse inner FV modules
                    ihdr = dec.find(b"_FVH", 0, 0x1000)
                    ibase = ihdr - 0x28
                    ilen = u64(dec, ibase + 0x20)
                    ioff = ibase + u16(dec, ibase + 0x30)
                    iend = min(len(dec), ibase + ilen)
                    while ioff + 0x18 <= iend:
                        it = dec[ioff + 0x12]
                        isz = (dec[ioff + 0x14] | (dec[ioff + 0x15] << 8)
                               | (dec[ioff + 0x16] << 16))
                        if isz < 0x18 or it == 0xFF:
                            break
                        ig = gstr(dec, ioff)
                        ibody = dec[ioff + 0x18: ioff + isz]
                        mods[ig] = (isz, sha(ibody))
                        ioff = (ioff + isz + 7) & ~7
        off = (off + size + 7) & ~7
    return mods, sec_sha, fvmain_len


def main(tag):
    fd = FW / f"SILICIUM_UEFI-{tag}.fd"
    img = OUT / f"Mu-vermeer-{tag}.img"
    for p in (fd, img, BASE_FD, BASE_IMG):
        if not p.exists():
            sys.exit(f"FATAL: missing {p}")

    fb = BASE_FD.read_bytes()
    ft = fd.read_bytes()
    mb, sb, lb = walk_fd(fb, "keys152")
    mt, st, lt = walk_fd(ft, tag)

    menu_guid = "4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"
    print(f"=== {tag} FD module diff vs keys152 ===")
    print(f"  modules: base={len(mb)} new={len(mt)}  added={len(set(mt)-set(mb))} removed={len(set(mb)-set(mt))}")
    changed = [g for g in sorted(set(mb) & set(mt)) if mb[g] != mt[g]]
    print(f"  changed={len(changed)}")
    for g in changed:
        b, t = mb[g], mt[g]
        note = " <-- MENU" if g == menu_guid else ""
        print(f"    {g}: size {b[0]} -> {t[0]}, sha {b[1][:8]} -> {t[1][:8]}{note}")
    print(f"  SEC/PEI FFS sha: base={sb} new={st}  {'OK (identical)' if sb == st else 'DIFF!'}")
    print(f"  inner FVMAIN len: base={lb} new={lt}  {'OK' if lb == lt else 'DIFF!'}")
    print(f"  FD sha256: {sha(ft)}  ({len(ft)} B)")

    # ---- container ---------------------------------------------------------
    import zlib

    ib = BASE_IMG.read_bytes()
    it = img.read_bytes()
    ks = struct.unpack_from("<I", it, 8)[0]
    ps = struct.unpack_from("<I", it, 0x24)[0] or 0x800
    kpay = it[ps:ps + ks]
    d = zlib.decompressobj(31)
    kraw = d.decompress(kpay) + d.flush()
    dtb = d.unused_data
    shim = kraw[:0xC0]
    fd_in = kraw[0xC0:]
    print(f"=== {tag} container ===")
    print(f"  img size {len(it)} (base {len(ib)}), magic={it[:8]!r}, page=0x{ps:x}, kernel_size={ks}")
    print(f"  decompressed {len(kraw)} (shim 0xC0 + fd {len(fd_in)}), shim sha={sha(shim)[:16]}")
    print(f"  fd_in_img == fd file: {fd_in == ft}")
    bks = struct.unpack_from("<I", ib, 8)[0]
    bps = struct.unpack_from("<I", ib, 0x24)[0] or 0x800
    bpay = ib[bps:bps + bks]
    bd = zlib.decompressobj(31)
    bd.decompress(bpay)
    bdtb = bd.unused_data
    print(f"  DTB len {len(dtb)} at 0x{ps + len(kpay) - len(dtb):x}, magic={dtb[:4]!r}, sha256={sha(dtb)}")
    print(f"  DTB == keys152 DTB: {dtb == bdtb}")
    print(f"  img sha256: {sha(it)}")

    # ---- Menu markers / disascan ------------------------------------------
    menu_efi = pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64")
    cands = list(menu_efi.rglob("VermeerMenuDxe.efi"))
    if cands:
        med = cands[0]
        raw = med.read_bytes()
        print(f"=== Menu {med} size={len(raw)} ===")
        for m in (b"MENU154", b"USB154", b"MENU152B", b"UI152B", b"USB150"):
            n = raw.count(m.decode("ascii").encode("utf-16-le"))
            print(f"  utf16 {m.decode()}: {n}")
        asm = subprocess.run(["llvm-objdump", "-d", str(med)],
                             capture_output=True, text=True).stdout
        bad = "mov\tw8, #0xf004" in asm or "mov\tw8, #0xF004" in asm
        print(f"  GCC_GDSCR materialization present: {bad}  (expect False)")
    else:
        print("=== Menu EFI not found (build dir) ===")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "keys154")
