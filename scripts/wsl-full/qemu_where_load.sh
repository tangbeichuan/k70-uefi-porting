#!/usr/bin/env bash
# Where did QEMU actually place the 256-byte payload?  Test A paints correctly, but
# 0xA7100000 reads back zero, so find the real load address and settle whether the
# arm64 image header's text_offset is honoured for a tiny image.
set -uo pipefail
W=/root/k70/qemu-test; mkdir -p "$W"; cd "$W"
printf 'pmemsave 0x40000000 0x04000000 %s/ram-low.bin\nquit\n' "$W" \
  | timeout 30 qemu-system-aarch64 -M virt -cpu cortex-a72 -m 3072 \
      -display none -serial null -monitor stdio -kernel /root/k70/paintonly/paint.bin >/dev/null 2>&1
ls -l ram-low.bin
python3 - "$W/ram-low.bin" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
pat = bytes.fromhex('1300b7d2')          # movz x19, #0xB800, lsl #16
i = d.find(pat)
print('movz x19 found at', hex(0x40000000 + i) if i >= 0 else 'not in 0x40000000..0x44000000')
if i >= 0:
    print('  header before it:', d[max(0, i - 0x44):i - 0x44 + 0x40].hex())
PY
