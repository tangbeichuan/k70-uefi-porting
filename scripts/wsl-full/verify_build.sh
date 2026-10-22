#!/usr/bin/env bash
# Inspect what we just built: FD header, module list, boot image header.
set +e
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
IMG=/root/k70/uefi/Mu-vermeer.img
python3 - "$FV" "$IMG" <<'PY'
import struct, sys, hashlib

fv_path, img_path = sys.argv[1], sys.argv[2]
fd = open(fv_path, "rb").read()
print(f"=== {fv_path}: {len(fd)} bytes  sha256={hashlib.sha256(fd).hexdigest()[:16]}...")
i = fd.find(b"_FVH")
print(f"first _FVH at offset 0x{i:x}")
if i > 0:
    base = i - 0x28
    (zero, fsguid, fvlen, sig, attr, hdrlen, csum, ext, rev) = struct.unpack_from("<16s16sQ4sIIIHH", fd, base)
    print(f"  FV base=0x{base:x} len=0x{fvlen:x} ({fvlen/1024/1024:.2f} MiB) hdrlen=0x{hdrlen:x} rev=0x{rev:x}")
    # walk FFS files in the FV
    off = base + hdrlen
    end = base + fvlen
    names = []
    while off + 24 <= end:
        hdr = fd[off:off+24]
        if hdr[:16] == b"\xff"*16:
            break
        guid = hdr[:16]
        (hdr_checksum, file_checksum, ftype, attrs, size3) = struct.unpack_from("<BBBB3s", hdr, 16)
        size = size3[0] | size3[1] << 8 | size3[2] << 16
        if size < 24:
            break
        names.append((hex(off), ftype, size))
        off += (size + 7) & ~7
    print(f"  FFS files: {len(names)}  (dxe/driver types: " +
          ", ".join(f"{t}:{sum(1 for _,tt,_ in names if tt==t)}" for t in sorted({t for _,t,_ in names})) + ")")

img = open(img_path, "rb").read()
print(f"\n=== {img_path}: {len(img)} bytes")
magic = img[:8]
print(f"  magic={magic!r}")
if magic == b"ANDROID!":
    (kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size, second_addr,
     tags_addr, page_size, header_version, os_version) = struct.unpack_from("<10I", img, 8)
    print(f"  header_version={header_version} page_size={page_size}")
    print(f"  kernel_size={kernel_size} (0x{kernel_size:x}) kernel_addr=0x{kernel_addr:x}")
    print(f"  ramdisk_size={ramdisk_size} second_size={second_size} tags_addr=0x{tags_addr:x}")
    print(f"  os_version=0x{os_version:x}")
    # page-aligned kernel payload: check for gzip magic and appended DTB
    page = page_size or 2048
    kstart = page
    kend = kstart + kernel_size
    print(f"  kernel @0x{kstart:x}..0x{kend:x} first bytes: {img[kstart:kstart+4].hex()}")
    blob = img[kstart:kend]
    # find FDT magic inside the kernel payload (appended DTB)
    pos = blob.find(b"\xd0\x0d\xfe\xed")
    print(f"  FDT magic inside kernel payload: {'0x%x' % pos if pos >= 0 else 'NOT FOUND'}")
    gz = blob.find(b"\x1f\x8b\x08")
    print(f"  gzip magic inside kernel payload: {'0x%x' % gz if gz >= 0 else 'NOT FOUND'}")
PY
echo
echo "=== BootShim: how does it locate the FV? ==="
grep -nE 'FD_BASE|FD_SIZE|_FVH|0x1000|MOV|LDR' /root/k70/uefi/BootShim/BootShim.S | head -25
