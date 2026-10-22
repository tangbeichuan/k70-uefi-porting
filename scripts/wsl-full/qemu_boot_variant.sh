#!/usr/bin/env bash
# Boot the QEMU-tuned FD and dump the frame-buffer serial log.
#   run 1: plain boot, 25 s   -> see how far DXE gets once the GIC addresses match
set -uo pipefail
W=/root/k70/qemu-fw
SHIM=/root/k70/shims/BootShim-marker0.bin
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-qemu.fd
OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
SECS=${1:-25}
SMP=${2:-8}
TAG=${3:-qemu}
cd "$W"

python3 - "$SHIM" "$FD" "$W/fw.bin" <<'PY'
import struct, sys
shim = open(sys.argv[1], 'rb').read(); fd = open(sys.argv[2], 'rb').read()
body = shim + fd
assert struct.unpack_from('<Q', body, 8)[0] == 0xA7100000
assert struct.unpack_from('<Q', body, 16)[0] == len(body)
open(sys.argv[3], 'wb').write(body)
print(f'composite {len(body)} B (shim {len(shim)} + FV {len(fd)})')
PY

echo "=== booting $SMP cpus for ${SECS}s ==="
rm -f "$W/fb.bin"
(
  sleep "$SECS"
  echo "pmemsave 0xb8000000 0x02b00000 fb.bin"
  sleep 3
  echo "quit"
) | timeout $((SECS + 60)) qemu-system-aarch64 -M virt,gic-version=3 -cpu max -smp "$SMP" -m 3072 \
      -display none -serial null -monitor stdio -kernel "$W/fw.bin" 2>&1 \
    | tr -d '\r' | grep -a -vE '^\s*$' | tail -5
mv -f "$W/fb.bin" "$OUT/fb-$TAG.bin" 2>/dev/null
ls -l "$OUT/fb-$TAG.bin" 2>&1
