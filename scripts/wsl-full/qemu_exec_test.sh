#!/usr/bin/env bash
# Execute the bring-up payloads under QEMU -- the only execution evidence available
# without the phone.
#
# Test A: the 256-byte paint payload alone.  QEMU's arm64 boot path reads the very
#         same arm64 image header the K70 bootloader reads (text_offset at 0x08,
#         image_size at 0x10, "ARMd" magic at 0x38), copies the image to 0xA7100000
#         and jumps to it.  Then we look at 0xB8000000 through the QEMU monitor.
# Test B: BootShim + the same payload used as a stand-in "FV", padded to the real
#         3 MiB and gzipped.  This exercises the gzip wrapper, the shim's 3 MiB
#         copy loop, its cache maintenance and the final `br x5` -- i.e. everything
#         between the bootloader and the first instruction of the firmware.
set -uo pipefail
WORK=/root/k70/qemu-test
PAINT=/root/k70/paintonly/paint.bin
SHIM=/root/k70/shims/BootShim-192.bin
mkdir -p "$WORK"
cd "$WORK"

FB=0xb8000000
BAND=0xb8100000

run_case() {
  local label="$1" kernel="$2" extra_args="$3"
  echo "===== $label ====="
  echo "  kernel: $kernel ($(stat -c%s "$kernel") B)"
  (
    sleep 4
    echo "xp /8wx $FB"
    echo "xp /8wx $BAND"
    sleep 2
    echo "xp /8wx $FB"
    echo "quit"
  ) | timeout 25 qemu-system-aarch64 -M virt -cpu cortex-a72 -m 3072 \
        -display none -serial null -monitor stdio $extra_args \
        -kernel "$kernel" 2>&1 | sed 's/^/  /'
  echo
}

# Test A: payload only
run_case "A: paint payload only (no shim, no firmware)" "$PAINT" ""

# Test B: shim + payload-padded-to-3MiB, gzipped (the real container layout)
python3 - "$SHIM" "$PAINT" "$WORK/shim-plus-payload.bin" <<'PY'
import sys
shim = open(sys.argv[1], 'rb').read()
paint = open(sys.argv[2], 'rb').read()
fd_size = 0x300000
body = shim + paint
body += b'\x00' * (fd_size - len(paint))
assert len(body) == len(shim) + fd_size
import struct
text_off, image_size = struct.unpack_from('<QQ', body, 8)
assert text_off == 0xA7100000, hex(text_off)
assert image_size == len(body), (hex(image_size), hex(len(body)))
open(sys.argv[3], 'wb').write(body)
print(f'  built shim+paint blob {len(body)} B (image_size 0x{image_size:x})')
PY
python3 - "$WORK/shim-plus-payload.bin" "$WORK/shim-plus-payload.bin.gz" <<'PY'
import gzip, sys
raw = open(sys.argv[1], 'rb').read()
with gzip.GzipFile(filename='', fileobj=open(sys.argv[2], 'wb'), mode='wb', mtime=0) as g:
    g.write(raw)
print(f'  gzip {len(open(sys.argv[2], "rb").read())} B')
PY
run_case "B: BootShim + payload as stand-in FV (gzipped, real layout)" "$WORK/shim-plus-payload.bin.gz" ""
