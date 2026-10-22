#!/usr/bin/env bash
set +e
R=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/BUILD_REPORT.TXT
echo "===== the one Binaries/vermeer line ====="
grep -n 'Binaries/vermeer' "$R"
echo
echo "===== modules in the FV (from BUILD_REPORT) ====="
grep -oE '0x[0-9A-Fa-f]+ [A-Za-z0-9_]+ \(' "$R" | sed 's/0x[0-9A-Fa-f]* //; s/ ($//' | sort -u | tr '\n' ' ' | fold -w 190
echo
echo
echo "===== FFS file count in the final FD ====="
python3 - <<'PY'
import struct
fd = open("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd", "rb").read()
i = fd.find(b"_FVH")
base = i - 0x28
fvlen = struct.unpack_from("<Q", fd, base + 0x20)[0]
hdrlen = struct.unpack_from("<H", fd, base + 0x30)[0]
print(f"FV base=0x{base:x} fvlen=0x{fvlen:x} hdrlen=0x{hdrlen:x}")
off, end, n, types = base + hdrlen, base + fvlen, 0, {}
while off + 24 <= end:
    hdr = fd[off:off + 24]
    if hdr == b"\xff" * 24 or hdr[:16] == b"\x00" * 16:
        break
    t = hdr[18]
    sz = hdr[19] | hdr[20] << 8 | hdr[21] << 16
    if sz < 24 or off + sz > end:
        print(f"  stop: bad header at 0x{off:x} type={t} size={sz}")
        break
    types[t] = types.get(t, 0) + 1
    off += (sz + 7) & ~7
    n += 1
print(f"FFS files={n} types={ {hex(k): v for k, v in sorted(types.items())} }")
PY
