#!/usr/bin/env bash
# Boot the QEMU-only firmware variant (PL011 serial DEBUG) under qemu-system-aarch64 and
# capture the DEBUG log as plain text.
#
# The phone's firmware prints through FrameBufferSerialPortLib (pixels into 0xB8000000);
# this variant prints through the QEMU PL011 at 0x09000000 instead, so `-serial file:` turns
# the same log into a text file we can grep.  Everything else is identical, including the
# BootShim that relocates the 3 MiB FV to FD_BASE and branches to it.
set -uo pipefail
FB_OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
WORK=/root/k70/qemu-serial
FD=$FB_OUT/SILICIUM_UEFI-qemu-serial.fd
SHIM=/root/k70/shims/BootShim-marker0.bin
SECS=${1:-25}
mkdir -p "$WORK"
cd "$WORK"

python3 - "$SHIM" "$FD" "$WORK/composite.bin" <<'PY'
import struct, sys
shim = open(sys.argv[1], 'rb').read()
fd   = open(sys.argv[2], 'rb').read()
comp = shim + fd
# sanity: arm64 image header written by BootShim must describe the composite
to, isz, magic = struct.unpack_from('<Q', comp, 0x08)[0], struct.unpack_from('<Q', comp, 0x10)[0], struct.unpack_from('<I', comp, 0x38)[0]
assert magic == 0x644d5241, hex(magic)
assert isz == len(comp), (hex(isz), len(comp))
open(sys.argv[3], 'wb').write(comp)
print(f'composite: {len(comp)} bytes  text_offset={to:#x}  image_size={isz:#x}  shim={len(shim)}')
PY

rm -f serial.log
echo "=== booting (${SECS}s timeout, serial -> serial.log) ==="
timeout "$SECS" qemu-system-aarch64 \
  -M virt,gic-version=3 -cpu max -m 3072 -smp 8 \
  -display none -monitor none -serial "file:$WORK/serial.log" \
  -kernel "$WORK/composite.bin" >/dev/null 2>&1
rc=$?
echo "qemu exit: $rc (124 = timed out, which is what we want)"
echo
echo "=== serial log: $(wc -c < "$WORK/serial.log" 2>/dev/null || echo 0) bytes, $(wc -l < "$WORK/serial.log" 2>/dev/null || echo 0) lines ==="
if [ -s "$WORK/serial.log" ]; then
  cp -f "$WORK/serial.log" "$FB_OUT/qemu-serial.log"
  sed 's/\r$//' "$WORK/serial.log" | tail -40
else
  echo "!! no serial output - PL011 not writing; check PcdSerialRegisterBase / clock"
fi
