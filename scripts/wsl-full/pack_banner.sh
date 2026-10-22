#!/usr/bin/env bash
# Package the banner diagnostic firmware (VERMEER_BANNER = 1) as boot images.
#
# Four images from ONE payload, because the first phone experiment should answer as many
# questions as possible per attempt:
#
#   name                    container  shim            what a screen difference means
#   Mu-vermeer-banner.img       v1      192 B plain     firmware is alive (heartbeat)
#   Mu-vermeer-banner-marker.img v1      304 B bands     + "did BootShim itself run"
#   Mu-vermeer-banner-v4.img    v4      192 B plain     same, for a v4-only bootloader
#   Mu-vermeer-banner-marker-v4 v4      304 B bands     same, with the bands
#
# The marker shim paints a magenta band before it stages the FV and a green band after, so
# even if EDK2 dies instantly the screen still tells you the bootloader accepted the image
# and our code executed.  gzip is written with mtime=0, so re-running this script is
# byte-for-byte reproducible.
set -e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
OUT=/mnt/d/本地项目-01/K70-UEFI-build
WORK=/root/k70
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-banner.fd
DTB=Resources/DTBs/vermeer.dtb
TOOLS=/mnt/d/本地项目-01/_k70port_extract

[ -f "$FD" ] || { echo "missing banner FV: $FD"; exit 1; }
[ -f "$DTB" ] || { echo "missing device tree: $DTB"; exit 1; }

for shim in /root/k70/shims/BootShim-marker0.bin /root/k70/shims/BootShim-marker1.bin; do
    [ -f "$shim" ] || { echo "missing shim: $shim"; exit 1; }
    case "$shim" in
        *marker0*) suffix="" ;;
        *marker1*) suffix="-marker" ;;
    esac

    echo "--- container set for shim $(basename "$shim") ($(stat -c %s "$shim") B) ---"

    # v1: gzip(shim || FV) then the DTB appended after the gzip member (append_dtb behaviour)
    python3 - "$FD" "$shim" "$DTB" "$WORK/vermeer-kernel-banner$suffix" <<'PY'
import gzip, io, sys
fd, shim, dtb = (open(p, "rb").read() for p in sys.argv[1:4])
buf = io.BytesIO()
with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0) as g:
    g.write(shim)
    g.write(fd)
gz = buf.getvalue()
open(sys.argv[4], "wb").write(gz + dtb)
print(f"  v1 kernel = gzip({len(shim)} + {len(fd)}) {len(gz)} B + DTB {len(dtb)} B")
PY
    python3 Resources/Scripts/mkbootimg.py --kernel "$WORK/vermeer-kernel-banner$suffix" \
        --ramdisk Resources/ramdisk --header_version 1 \
        -o "$OUT/Mu-vermeer-banner$suffix.img"

    # v4: same payload, page 4096, no DTB in the container (v4 has no dtb field)
    python3 "$TOOLS/package_v4.py" --fd "$FD" --shim "$shim" \
        --out "$OUT/Mu-vermeer-banner$suffix-v4.img"
done

cd "$OUT" && sha256sum Mu-vermeer-banner*.img
