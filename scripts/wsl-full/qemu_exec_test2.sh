#!/usr/bin/env bash
# Execute the bring-up payloads under QEMU and read back the frame-buffer window.
#
# Two boots:
#   A  the 256-byte paint payload on its own (QEMU reads the same arm64 image header
#      the K70 bootloader reads: text_offset 0x08, image_size 0x10, "ARMd" 0x38)
#   B  BootShim + the payload standing in for the 3 MiB FV: this exercises the shim's
#      copy loop, cache maintenance and the final `br x5`
set -uo pipefail
WORK=/root/k70/qemu-test
PAINT=/root/k70/paintonly/paint.bin
SHIM=/root/k70/shims/BootShim-marker0.bin
mkdir -p "$WORK"
cd "$WORK"

monitor_dump() {  # $1 = label, $2 = kernel path
  local label="$1" kernel="$2"
  echo "===== $label ====="
  echo "  kernel $(basename "$kernel")  $(stat -c%s "$kernel") B"
  (
    sleep 5
    for addr in 0xb8000000 0xb8100000 0xb8400000 0xb8100010 0xb82b0000 0xb82af000; do
      echo "xp /2wx $addr"
    done
    sleep 2
    echo "xp /2wx 0xb8000000"
    echo "quit"
  ) | timeout 30 qemu-system-aarch64 -M virt -cpu cortex-a72 -m 3072 \
        -display none -serial null -monitor stdio -kernel "$kernel" 2>&1 \
      | tr -d '\r' | grep -E '^(0x[0-9a-f]{16}:|[0-9a-f]{16}:)' | sed 's/^/  /'
  echo
}

monitor_dump "A: paint payload only" "$PAINT"

python3 - "$SHIM" "$PAINT" "$WORK/shim-plus-paint.bin" <<'PY'
import struct, sys
shim = open(sys.argv[1], 'rb').read()
paint = open(sys.argv[2], 'rb').read()
fd_size = 0x300000
body = shim + paint + b'\x00' * (fd_size - len(paint))
assert len(body) == len(shim) + fd_size
text_off, image_size = struct.unpack_from('<QQ', body, 8)
assert text_off == 0xA7100000, hex(text_off)
assert image_size == len(body), (hex(image_size), hex(len(body)))
assert struct.unpack_from('<I', body, 0x38)[0] == 0x644D5241
open(sys.argv[3], 'wb').write(body)
print(f'  built shim+payload {len(body)} B, header ok (text_offset 0x{text_off:x}, image_size 0x{image_size:x})')
PY

monitor_dump "B: BootShim + payload as stand-in FV" "$WORK/shim-plus-paint.bin"
