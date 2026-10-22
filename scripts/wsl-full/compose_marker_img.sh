#!/usr/bin/env bash
# Compose the bring-up-marker boot image from the PUBLISHED firmware, so both images
# carry a byte-identical FV and the only difference is which BootShim runs:
#   Mu-vermeer.img         -> 192-byte shim, leaves the bootloader splash alone
#   Mu-vermeer-marker.img  -> 304-byte shim, paints two progress bands into it
# Kernel layout must match build_uefi.py:  gzip(shim || FV) || DTB
set -e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
OUT=/mnt/d/本地项目-01/K70-UEFI-build
SHIM=/root/k70/shims/BootShim-marker1.bin
DTB=Resources/DTBs/vermeer.dtb

[ -f "$SHIM" ] || { echo "missing marker shim: $SHIM"; exit 1; }
[ -f "$DTB" ]  || { echo "missing device tree: $DTB"; exit 1; }

python3 - "$OUT/SILICIUM_UEFI.fd" "$SHIM" "$DTB" /root/k70/vermeer-kernel-marker <<'PY'
import gzip, io, sys
fd_path, shim_path, dtb_path, out_path = sys.argv[1:5]
fd, shim, dtb = (open(p, "rb").read() for p in (fd_path, shim_path, dtb_path))
buf = io.BytesIO()
with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0) as g:
    g.write(shim)
    g.write(fd)
gz = buf.getvalue()
open(out_path, "wb").write(gz + dtb)
print(f"  gzip(shim {len(shim)} B + FV {len(fd)} B) = {len(gz)} B, + DTB {len(dtb)} B"
      f" => kernel {len(gz) + len(dtb)} B")
PY

python3 Resources/Scripts/mkbootimg.py --kernel /root/k70/vermeer-kernel-marker \
    --ramdisk Resources/ramdisk --header_version 1 -o "$OUT/Mu-vermeer-marker.img"
echo "  wrote $OUT/Mu-vermeer-marker.img ($(stat -c %s "$OUT/Mu-vermeer-marker.img") bytes)"
