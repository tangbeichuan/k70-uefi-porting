#!/usr/bin/env bash
# Package a diagnostic firmware as boot images.
#   pack_keys.sh <fd-path> <tag>
# Produces, in K70-UEFI-build:
#   Mu-vermeer-<tag>.img      v1 container, 192 B plain shim
#   Mu-vermeer-<tag>-marker.img v1 container, 304 B shim that paints magenta/green bands
#   Mu-vermeer-<tag>-v4.img   v4 container, 192 B shim
set -e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate

FD=$1
TAG=$2
[ -f "$FD" ] || { echo "missing FD: $FD"; exit 1; }
OUT=/mnt/d/本地项目-01/K70-UEFI-build
WORK=/root/k70
DTB=Resources/DTBs/vermeer.dtb
TOOLS=/mnt/d/本地项目-01/_k70port_extract

for shim in /root/k70/shims/BootShim-marker0.bin /root/k70/shims/BootShim-marker1.bin; do
    case "$shim" in
        *marker0*) suffix="" ;;
        *marker1*) suffix="-marker" ;;
    esac
    echo "--- $TAG$suffix : shim $(basename "$shim") $(stat -c %s "$shim") B ---"

    python3 - "$FD" "$shim" "$DTB" "$WORK/kernel-$TAG$suffix" <<'PY'
import gzip, io, sys
fd, shim, dtb = (open(p, "rb").read() for p in sys.argv[1:4])
buf = io.BytesIO()
with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0) as g:
    g.write(shim)
    g.write(fd)
gz = buf.getvalue()
open(sys.argv[4], "wb").write(gz + dtb)
print(f"  kernel = gzip({len(shim)}+{len(fd)}) {len(gz)} B + DTB {len(dtb)} B")
PY
    python3 Resources/Scripts/mkbootimg.py --kernel "$WORK/kernel-$TAG$suffix" \
        --ramdisk Resources/ramdisk --header_version 1 \
        -o "$OUT/Mu-vermeer-$TAG$suffix.img"

    [ "$suffix" = "" ] && python3 "$TOOLS/package_v4.py" --fd "$FD" --shim "$shim" \
        --out "$OUT/Mu-vermeer-$TAG-v4.img"
done

cd "$OUT" && sha256sum Mu-vermeer-$TAG.img Mu-vermeer-$TAG-marker.img Mu-vermeer-$TAG-v4.img 2>/dev/null | tee /tmp/$TAG.sha
