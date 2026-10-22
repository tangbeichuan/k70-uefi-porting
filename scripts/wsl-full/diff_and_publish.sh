#!/usr/bin/env bash
# Where do the 24 bytes differ between two identical from-scratch builds, and
# publish the newest build as the official artifact set.
set +e
cd /root/k70/uefi || exit 1
A=/root/k70/fd-clean-1.fd
B=Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
echo "=== differing offsets between the two builds ==="
cmp -l "$A" "$B" | awk '{printf "  0x%06x  %s -> %s\n", $1-1, $2, $3}' | head -30
echo
echo "=== context of the first difference inside build 1 ==="
first=$(cmp -l "$A" "$B" | head -1 | awk '{print $1-1}')
python3 - "$A" "$first" <<'PY'
import sys
path, off = sys.argv[1], int(sys.argv[2])
d = open(path, 'rb').read()
lo = max(0, off - 32)
print(f"  offset 0x{off:06x}")
print("  hex:", d[lo:lo+64].hex())
print("  ascii:", ''.join(chr(b) if 32 <= b < 127 else '.' for b in d[lo:lo+64]))
PY

echo
echo "=== publish newest build ==="
OUT=/mnt/d/本地项目-01/K70-UEFI-build
cp -f "$B" "$OUT/SILICIUM_UEFI.fd"
cp -f Mu-vermeer.img "$OUT/Mu-vermeer.img"
cp -f Build/vermeerPkg/DEBUG_CLANGPDB/BUILD_REPORT.TXT "$OUT/BUILD_REPORT.TXT"
cp -f /root/k70/build-clean2.log "$OUT/BUILDLOG_vermeerPkg.txt"
cd "$OUT" && sha256sum *.fd *.img *.tar.gz *.TXT 2>/dev/null | grep -v vendorhw-DO-NOT-FLASH | sort -k2 > SHA256SUMS.txt
cat SHA256SUMS.txt
