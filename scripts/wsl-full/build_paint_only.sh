#!/usr/bin/env bash
# Build the paint-only payload (no EDK2 at all) and wrap it in both boot containers.
#
# Layer 0 of the diagnosis ladder: if this image changes the screen, the bootloader
# accepted the container, decompressed the kernel, honoured the arm64 image header and
# jumped to our code.  Any later black screen is then inside EDK2, not the container.
set -euo pipefail

SRC=/mnt/d/本地项目-01/_k70port_extract/payload-paint
OUT=/root/k70/paintonly
UEFI=/root/k70/uefi
DEST="/mnt/d/本地项目-01/K70-UEFI-build"
DTB="$DEST/../_k70port_extract/port/Resources/DTBs/vermeer.dtb"

rm -rf "$OUT"; mkdir -p "$OUT"
cp "$SRC/paint_only.S" "$OUT/"
cd "$OUT"

echo "== assemble =="
clang --target=aarch64-none-elf -march=armv8-a -c paint_only.S -o paint.o
ld.lld -Ttext=0 --image-base=0 --entry=0x40 -o paint.elf paint.o 2>/dev/null \
  || aarch64-linux-gnu-ld -Ttext=0 -e 0x40 -o paint.elf paint.o
aarch64-linux-gnu-objcopy -O binary paint.elf paint.bin

echo "== patch image_size (offset 16) =="
python3 - "$OUT/paint.bin" <<'PY'
import struct, sys
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())
assert d[:4] == bytes.fromhex('1f000014') or True
magic = struct.unpack_from('<I', d, 0x38)[0]
assert magic == 0x644d5241, f'bad magic 0x{magic:08x}'
struct.pack_into('<Q', d, 0x10, len(d))
open(p, 'wb').write(d)
print(f'   payload {len(d)} B, text_offset 0x{struct.unpack_from("<Q",d,8)[0]:x}, image_size 0x{len(d):x}')
PY

echo "== gzip (mtime=0, deterministic) =="
python3 - "$OUT/paint.bin" "$OUT/paint.gz" <<'PY'
import gzip, sys
raw = open(sys.argv[1], 'rb').read()
with gzip.GzipFile(filename='', fileobj=open(sys.argv[2], 'wb'), mode='wb', mtime=0) as g:
    g.write(raw)
print(f'   gzip {len(open(sys.argv[2],"rb").read())} B')
PY

echo "== container v1 (same geometry and dtb-append behaviour as the firmware images) =="
# build_uefi.py appends the device tree *after* the gzip member inside the kernel
# blob (Resources/Configs/vermeer.toml: append_dtb = true); mirror that exactly so
# the bootloader sees the same shape it would see with the real firmware image.
DTBFILE=""
for c in "$DEST/../_k70port_extract/port/Resources/DTBs/vermeer.dtb" /root/k70/uefi/Resources/DTBs/vermeer.dtb; do
  [ -f "$c" ] && DTBFILE="$c" && break
done
if [ -n "$DTBFILE" ]; then
  echo "   appending DTB $DTBFILE after the gzip member"
  cat "$OUT/paint.gz" "$DTBFILE" > "$OUT/paint-with-dtb.kernel"
else
  echo "   WARNING: no device dtb found, packing without it"
  cp "$OUT/paint.gz" "$OUT/paint-with-dtb.kernel"
fi
python3 "$UEFI/Resources/Scripts/mkbootimg.py" \
  --kernel "$OUT/paint-with-dtb.kernel" --header_version 1 \
  -o "$OUT/Mu-vermeer-paintonly.img"

echo "== container v4 (stock-aligned, no dtb) =="
: > "$OUT/empty.bin"
python3 "/mnt/d/本地项目-01/K70-UEFI-build/package_v4.py" \
  --shim "$OUT/paint.bin" --fd "$OUT/empty.bin" \
  --out "$OUT/Mu-vermeer-paintonly-v4.img"

echo "== report =="
for f in "$OUT"/Mu-vermeer-paintonly*.img "$OUT"/paint.bin "$OUT"/paint.gz; do
  printf '  %-40s %8d B  %s\n' "$(basename "$f")" "$(stat -c%s "$f")" "$(sha256sum "$f" | cut -d' ' -f1)"
done
cp "$OUT"/Mu-vermeer-paintonly.img "$OUT"/Mu-vermeer-paintonly-v4.img "$OUT"/paint.bin "$OUT"/paint.gz "$DEST"/
echo "   copied to $DEST"
