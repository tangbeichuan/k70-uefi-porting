#!/usr/bin/env bash
# Final boundary evidence for the paint payload under QEMU.
#
# Window under test: 0xB8000000 .. 0xB8000000 + 0x02B00000 = 0xBAB00000 (43 MiB)
#   band       = first 4 MiB           -> palette colour, advances every 0.5 s
#   background = the other 39 MiB      -> 0x00601008
#   at 0xBAB00000 and beyond           -> untouched, reads back zero
#
# (note 0x02B00000 = 43 MiB, so the window end is 0xBAB00000 -- the DXE Heap start in
#  the K70 stock memory map, which is why the window may not grow any further)
set -uo pipefail
WORK=/root/k70/qemu-test
PAINT=/root/k70/paintonly/paint.bin
SHIM=/root/k70/shims/BootShim-marker0.bin
mkdir -p "$WORK"; cd "$WORK"

probe() {  # $1 label, $2 kernel
  echo "##### $1 ($(basename "$2"), $(stat -c%s "$2") B)"
  (
    sleep 5
    echo "xp /2wx 0xb8000000"   # band start              -> palette
    echo "xp /2wx 0xb83ffff0"   # last 16 B of band       -> palette
    echo "xp /2wx 0xb8400000"   # 4 MiB, first bg byte    -> 0x00601008
    echo "xp /2wx 0xbaaffff0"   # 43 MiB - 16, last bg    -> 0x00601008
    echo "xp /2wx 0xbab00000"   # 43 MiB, past window     -> 0x00000000
    echo "xp /2wx 0xbac00000"   # 44 MiB, past window     -> 0x00000000
    echo "xp /2wx 0xa7100000"   # FD_BASE: header words of the loaded image
    echo "xp /2wx 0x40080000"   # QEMU virt default load address (check it is unused)
    sleep 2
    echo "xp /2wx 0xb8000000"   # band again -> colour advanced
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
