#!/usr/bin/env bash
# Boot the REAL firmware under QEMU and dump the frame-buffer serial log.
#
# The container ABL builds is `gzip(shim || FV)`; the bootloader decompresses it to
# 0x10008000 and jumps, then the shim copies FV to FD_BASE.  QEMU's -kernel path reads the
# same arm64 image header, so handing it the *uncompressed* composite places the shim at
# FD_BASE and runs SEC exactly like the phone would.
#
# FrameBufferSerialPortLib writes DEBUG text into the "Display Reserved" window at
# 0xB8000000 as pixels (built-in 8x16 font), so dumping that window recovers the log.
#
#   -machine virt,gic-version=3  -> ArmGicDxe can use the GICv3 system registers
#   -cpu max                     -> AArch64 feature set SEC expects
set -uo pipefail
W=/root/k70/qemu-fw
SHIM=/root/k70/shims/BootShim-marker0.bin
FD=/mnt/d/本地项目-01/K70-UEFI-build/SILICIUM_UEFI.fd
OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
mkdir -p "$W" "$OUT"; cd "$W"

python3 - "$SHIM" "$FD" "$W/fw.bin" <<'PY'
import struct, sys
shim = open(sys.argv[1], 'rb').read()
fd = open(sys.argv[2], 'rb').read()
body = shim + fd
text_off, image_size = struct.unpack_from('<QQ', body, 8)
assert text_off == 0xA7100000, hex(text_off)
assert image_size == len(body), (hex(image_size), hex(len(body)))
assert struct.unpack_from('<I', body, 0x38)[0] == 0x644D5241
open(sys.argv[3], 'wb').write(body)
print(f'composite: shim {len(shim)} B + FV {len(fd)} B = {len(body)} B (image_size 0x{image_size:x})')
PY

echo "=== booting under QEMU (20 s, then dump 43 MiB frame-buffer window) ==="
(
  sleep 20
  echo "pmemsave 0xb8000000 0x02b00000 fb.bin"
  sleep 4
  echo "quit"
) | timeout 90 qemu-system-aarch64 -M virt,gic-version=3 -cpu max -m 3072 \
      -display none -serial null -monitor stdio -kernel "$W/fw.bin" 2>&1 \
    | tr -d '\r' | grep -a -vE '^\s*$' | tail -6
mv -f "$W/fb.bin" "$OUT/fb.bin" 2>/dev/null
ls -l "$OUT/fb.bin" 2>&1
python3 - "$OUT/fb.bin" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
nz = sum(1 for i in range(0, len(d), 4) if d[i:i+4] != b'\x00\x00\x00\x00')
print(f'dumped {len(d)} B; non-zero pixels: {nz}')
# report which 64 KiB pages changed, to localise what got painted
for page in range(0, len(d), 0x10000):
    chunk = d[page:page+0x10000]
    if any(chunk):
        print(f'  first touched page at 0x{0xB8000000+page:08x}')
        break
PY
