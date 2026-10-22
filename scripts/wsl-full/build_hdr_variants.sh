#!/usr/bin/env bash
# Build the remaining container flavours (header v2 and v3) for the firmware, so the
# first-boot ladder can cover every header version an ABL might insist on:
#
#   v1  kernel = gzip(shim||FV) + appended DTB      page 2048  (already shipped)
#   v2  kernel = gzip(shim||FV), DTB in the dtb field            <- this script
#   v3  kernel = gzip(shim||FV), no DTB, page 4096  (stock-style) <- this script
#   v4  kernel = gzip(shim||FV), page 4096, 1584 B header       (already shipped)
#
# The kernel payload bytes are identical in all four; only the container changes.
set -uo pipefail
UEFI=/root/k70/uefi
MK=$UEFI/Resources/Scripts/mkbootimg.py
OUT=/mnt/d/本地项目-01/K70-UEFI-build
W=/root/k70/containers
FD=$OUT/SILICIUM_UEFI.fd
SHIM=$OUT/BootShim-192.bin
DTB=$UEFI/Resources/DTBs/vermeer.dtb
mkdir -p "$W"; cd "$W"

python3 - "$SHIM" "$FD" "$W/kernel.bin" <<'PY'
import gzip, io, struct, sys
shim = open(sys.argv[1], 'rb').read()
fd = open(sys.argv[2], 'rb').read()
body = shim + fd
assert struct.unpack_from('<Q', body, 8)[0] == 0xA7100000
assert struct.unpack_from('<Q', body, 16)[0] == len(body)
raw = io.BytesIO()
with gzip.GzipFile(fileobj=raw, mode='wb', mtime=0) as g:
    g.write(body)
open(sys.argv[3], 'wb').write(raw.getvalue())
print(f'kernel payload: {len(body)} B -> gzip {len(raw.getvalue())} B')
PY

python3 "$MK" --kernel "$W/kernel.bin" --dtb "$DTB" \
    --header_version 2 --pagesize 2048 --kernel_offset 0x8000 --tags_offset 0x1e00000 \
    --output "$OUT/Mu-vermeer-v2.img"
python3 "$MK" --kernel "$W/kernel.bin" \
    --header_version 3 --pagesize 4096 \
    --output "$OUT/Mu-vermeer-v3.img"

cd "$OUT"
ls -l Mu-vermeer-v2.img Mu-vermeer-v3.img
sha256sum Mu-vermeer-v2.img Mu-vermeer-v3.img
