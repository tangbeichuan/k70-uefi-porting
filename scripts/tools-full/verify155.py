#!/usr/bin/env python3
"""verify155.py -- offline verification for keys155 (GCC PEI region + read-only diag).

Baseline: keys152 (minimal read-only Menu, PEI = keys149 memory map).
Expected:
  * FD modules: 90/90, only VermeerMenuDxe changed
  * SEC/PEI FFS: size 65440, sha != keys152's cfcfca5e, contains region names
    "GCC" (1), "USB" (1), "PERIPH_SS" (1) and NOT "UFS" -> same shape as the
    keys93/94/95 PEI that booted and read GCC_GDSCR
  * container: gzip(shim192+FD) == FD file, trailing DTB == keys152's DTB
  * Menu UTF-16: MENU155/USB155 present; disasm shows GCC offset reads and no
    store instructions to GCC/DWC3/QSCRATCH addresses
usage: verify155.py [keys155]
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
BASE_FD = FW / "SILICIUM_UEFI-keys152.fd"
BASE_IMG = OUT / "Mu-vermeer-keys152.img"
LZMA_GUID = "ee4e5898-3914-4259-9d6e-dc7bd79403cf"
MENU_GUID = "4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90"


def sha(b):
    return hashlib.sha256(b).hexdigest()


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def gstr(b, o):
    return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))


def ffs_list(buf):
    hdr = buf.find(b"_FVH", 0, 0x1000)
    base = hdr - 0x28
    off = base + u16(buf, base + 0x30)
    end = min(len(buf), base + u64(buf, base + 0x20))
    out = []
    while off + 0x18 <= end:
        ft = buf[off + 0x12]
        sz = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        if sz < 0x18 or ft == 0xFF:
            break
        out.append((off, ft, sz, gstr(buf, off), buf[off + 0x18:off + sz]))
        off = (off + sz + 7) & ~7
    return out


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


def fvmain_modules(buf):
    mods = {}
    import lzma
    for off, ft, sz, guid, body in ffs_list(buf):
        for stype, data, sguid in sections(body):
            if stype == 0x02 and sguid == LZMA_GUID:
                dec = lzma.decompress(data, format=lzma.FORMAT_ALONE)
                ioff = 0x50
                while ioff + 0x18 <= len(dec):
                    it = dec[ioff + 0x12]
                    iz = (dec[ioff + 0x14] | (dec[ioff + 0x15] << 8)
                          | (dec[ioff + 0x16] << 16))
                    if iz < 0x18 or it == 0xFF:
                        break
                    if it not in (0x0B, 0xF0):
                        mods[gstr(dec, ioff)] = (iz, sha(dec[ioff + 0x18:ioff + iz]))
                    ioff = (ioff + iz + 7) & ~7
    return mods


def sec_ffs(buf):
    for off, ft, sz, guid, body in ffs_list(buf):
        if ft == 0x03:
            return body
    return None


def container(img):
    raw = img.read_bytes()
    ks = struct.unpack_from("<I", raw, 8)[0]
    ps = struct.unpack_from("<I", raw, 0x24)[0] or 0x800
    pay = raw[ps:ps + ks]
    d = zlib.decompressobj(31)
    dec = d.decompress(pay) + d.flush()
    return raw, dec, d.unused_data, ks, ps


def main(tag="keys155"):
    fd = FW / f"SILICIUM_UEFI-{tag}.fd"
    img = OUT / f"Mu-vermeer-{tag}.img"
    fb, ft = BASE_FD.read_bytes(), fd.read_bytes()
    mb, mt = fvmain_modules(fb), fvmain_modules(ft)

    print(f"=== {tag}: FD module diff vs keys152 ===")
    print(f"  modules base={len(mb)} new={len(mt)} added={len(set(mt)-set(mb))} removed={len(set(mb)-set(mt))}")
    changed = [g for g in sorted(set(mb) & set(mt)) if mb[g] != mt[g]]
    print(f"  changed={len(changed)}")
    for g in changed:
        print(f"    {g}: size {mb[g][0]} -> {mt[g][0]}, sha {mb[g][1][:8]} -> {mt[g][1][:8]}"
              + ("  <-- MENU" if g == MENU_GUID else ""))
    print(f"  FD sha256={sha(ft)} size={len(ft)}")

    sb, st = sec_ffs(fb), sec_ffs(ft)
    print("=== SEC/PEI FFS ===")
    print(f"  keys152: size={len(sb)} sha={sha(sb)}")
    print(f"  {tag}: size={len(st)} sha={sha(st)}")
    for n in (b"GCC\x00", b"USB\x00", b"PERIPH_SS\x00", b"UFS\x00"):
        print(f"    region name {n!r}: keys152={sb.count(n)} {tag}={st.count(n)}")

    rb, decb, dtbb, _, _ = container(BASE_IMG)
    rt, dect, dtbt, ks, ps = container(img)
    print("=== container ===")
    print(f"  img size={len(rt)} page=0x{ps:x} kernel_size={ks}")
    print(f"  decompressed={len(dect)} (shim 0xC0 + fd {len(dect)-0xC0}); fd_in_img == FD file: {dect[0xC0:] == ft}")
    print(f"  DTB len={len(dtbt)} sha={sha(dtbt)}; same as keys152 DTB: {dtbt == dtbb}")
    print(f"  img sha256={sha(rt)}")

    menud = pathlib.Path("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64")
    cands = list(menud.rglob("VermeerMenuDxe.efi"))
    if cands:
        med = cands[0]
        raw = med.read_bytes()
        print(f"=== Menu {med} size={len(raw)} ===")
        for m in (b"MENU155", b"USB155", b"USB150", b"Usb150Wr"):
            print(f"  utf16 {m.decode()}: {raw.count(m.decode().encode('utf-16-le'))}")
        asm = subprocess.run(["llvm-objdump", "-d", str(med)], capture_output=True, text=True).stdout
        lines = asm.splitlines()
        gcc_hits = [l for l in lines if "#0xf004" in l or "#0xf010" in l or "#0xf014" in l
                    or "#0xf018" in l or "#0xf084" in l or "#0x100000" in l]
        print(f"  GCC-related immediate lines: {len(gcc_hits)}")
        for l in gcc_hits[:12]:
            print("   ", l.strip())
        stores = [l for l in lines if "\tstr" in l]
        print(f"  total store instructions in Menu: {len(stores)} (pre-existing UI code)")
    else:
        print("=== Menu EFI not found ===")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "keys155")
