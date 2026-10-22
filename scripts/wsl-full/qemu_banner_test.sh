set -uo pipefail
WORK=/root/k70/qemu-serial
FB_OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
FD=${1:-$FB_OUT/SILICIUM_UEFI-banner-qemu.fd}
TAG=${2:-banner}
SHIM=/root/k70/shims/BootShim-marker0.bin
mkdir -p "$WORK"; cd "$WORK"

python3 - "$SHIM" "$FD" "$WORK/composite-$TAG.bin" <<'PY'
import struct, sys
shim = open(sys.argv[1],'rb').read(); fd = open(sys.argv[2],'rb').read()
comp = shim + fd
isz = struct.unpack_from('<Q', comp, 0x10)[0]
assert isz == len(comp), (hex(isz), len(comp))
open(sys.argv[3],'wb').write(comp)
print(f'composite {len(comp)} bytes (shim {len(shim)})')
PY

rm -f "serial-$TAG.log"
timeout 40 qemu-system-aarch64 \
  -M virt,gic-version=3 -cpu max -m 3072 -smp 8 \
  -display none -monitor none -serial "file:$WORK/serial-$TAG.log" \
  -kernel "$WORK/composite-$TAG.bin" >/dev/null 2>&1
echo "qemu exit: $? (124 = still running = the banner driver never returned, as designed)"
echo "=== $(wc -l < "serial-$TAG.log") lines, $(wc -c < "serial-$TAG.log") bytes ==="
sed 's/\r/\n/g' "serial-$TAG.log" | grep -n -A 20 "Redmi K70" | head -30
echo
echo "=== heartbeat lines (should keep increasing) ==="
sed 's/\r/\n/g' "serial-$TAG.log" | grep -o "heartbeat [0-9]*" | tail -5
cp -f "serial-$TAG.log" "$FB_OUT/qemu-serial-$TAG.log"
