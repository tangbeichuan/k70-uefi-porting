#!/usr/bin/env bash
# Boundary proof: run the paint payload under QEMU and check the exact edges of the
# region it claims to paint.
#
#   band      : 0xB8000000 .. 0xB8400000   (4 MiB, palette colour, cycles every 0.5 s)
#   background: the rest of the window      (0x00601008)
#   window end: 0xB82B0000                  (43 MiB) -- must be untouched (zero)
#
# If the length immediates are wrong (the 0x2B00-vs-0x02B0 class of bug) one of these
# edges moves, and the dump shows it.
set -uo pipefail
WORK=/root/k70/qemu-test
PAINT=/root/k70/paintonly/paint.bin
SHIM=/root/k70/shims/BootShim-marker0.bin
mkdir -p "$WORK"; cd "$WORK"

probe() {  # $1 label, $2 kernel
  echo "##### $1 ($(basename "$2"), $(stat -c%s "$2") B)"
  (
    sleep 5
    echo "xp /2wx 0xb8000000"   # band start
    echo "xp /2wx 0xb83ffff0"   # last 16 bytes of the band
    echo "xp /2wx 0xb8400000"   # first bytes after the band -> background
    echo "xp /2wx 0xb82afff0"   # last 16 bytes of the window -> background
    echo "xp /2wx 0xb82b0000"   # first bytes past the window -> untouched
    echo "xp /2wx 0xb9000000"   # well past the window -> untouched
    echo "xp /4wx 0xa7100000"   # where the image was loaded (header words)
    sleep 2
    echo "xp /2wx 0xb8000000"   # band again, 2 s later -> colour advanced
    echo "quit"
  ) | timeout 30 qemu-system-aarch64 -M virt -cpu cortex-a72 -m 3072 \
        -display none -serial null -monitor stdio -kernel "$2" 2>&1 \
      | tr -d '\r' | grep -E '^[0-9a-f]{16}:' | sed 's/^/  /'
  echo
}

probe "paint payload alone" "$PAINT"

python3 - "$SHIM" "$PAINT" "$WORK/shim-plus-paint.bin" <<'PY'
import struct, sys
shim = open(sys.argv[1], 'rb').read()
paint = open(sys.argv[2], 'rb').read()
body = shim + paint + b'\x00' * (0x300000 - len(paint))
assert struct.unpack_from('<Q', body, 8)[0] == 0xA7100000
assert struct.unpack_from('<Q', body, 16)[0] == len(body)
open(sys.argv[3], 'wb').write(body)
PY
probe "BootShim + payload as stand-in FV" "$WORK/shim-plus-paint.bin"
