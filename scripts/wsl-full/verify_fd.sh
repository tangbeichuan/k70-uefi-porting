#!/usr/bin/env bash
set +e
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
python3 - "$FV" <<'PY'
import struct, sys
fd = open(sys.argv[1], "rb").read()
i = fd.find(b"_FVH")
base = i - 0x28
(zero, fsguid, fvlen, sig, attr, hdrlen, csum, ext, rev) = struct.unpack_from("<16s16sQ4sIHHBB", fd, base)
print(f"FV base=0x{base:x} fvlen=0x{fvlen:x} hdrlen=0x{hdrlen:x} attr=0x{attr:x} rev={rev}")
off = base + hdrlen
end = base + fvlen
n = 0
types = {}
sizes = []
while off + 24 <= end:
    hdr = fd[off:off+24]
    if hdr == b"\xff" * 24:
        break
    if hdr[:16] == b"\x00" * 16:
        break
    t = hdr[18]
    sz = hdr[19] | hdr[20] << 8 | hdr[21] << 16
    if sz < 24 or off + sz > end:
        print(f"  !! bad FFS header at 0x{off:x} type={t} size={sz}")
        break
    types[t] = types.get(t, 0) + 1
    sizes.append((off, t, sz))
    off += (sz + 7) & ~7
    n += 1
print(f"FFS files: {n}  total payload {(off-base)/1024:.0f} KiB after header")
print("by type:", {hex(k): v for k, v in sorted(types.items())})
print("largest 8:", [(hex(o), t, s) for o, t, s in sorted(sizes, key=lambda x: -x[2])[:8]])
PY
echo
echo "===== is SimpleFbDxe in the build? ====="
grep -c 'SimpleFbDxe' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/BUILD_REPORT.TXT 2>/dev/null
grep -E 'SimpleFb|FrameBuffer|GraphicsConsole|ConSplitter|BdsDxe|ButtonsDxe|UFSDxe|DisplayDxe|ClockDxe' \
  /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/BUILD_REPORT.TXT 2>/dev/null | head -20
echo
echo "===== boot header version used by nuwa / sheng ====="
grep -n 'header_version\|boot_shim\|uefi_fd\|append_dtb\|kernel_compression' \
  /root/k70/uefi/Resources/Configs/nuwa.toml /root/k70/uefi/Resources/Configs/sheng.toml /root/k70/uefi/Resources/Configs/vermeer.toml 2>/dev/null
