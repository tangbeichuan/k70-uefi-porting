#!/usr/bin/env bash
# Build and publish three images from two builds:
#   build A (paint_marker=true)  -> Mu-vermeer-marker.img   (diagnostic ladder)
#   build B (paint_marker=false) -> SILICIUM_UEFI.fd + Mu-vermeer.img + Mu-vermeer-hdr0.img
# Both header variants are packed from the SAME staged kernel so the FV inside them
# stays byte-identical to the published .fd (see doc 8.6).
set -e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
OUT=/mnt/d/本地项目-01/K70-UEFI-build
CFG=Resources/Configs/vermeer.toml

setflag () {  # $1 = true|false
  python3 - "$1" <<'PY'
import re, sys
val = "true" if sys.argv[1] == "true" else "false"
p = "Resources/Configs/vermeer.toml"
s = open(p, encoding="utf-8").read()
if re.search(r"(?m)^paint_marker\s*=", s):
    s = re.sub(r"(?m)^paint_marker\s*=.*$", f"paint_marker = {val}", s)
else:
    s = s.replace("requires_kernel_header = true",
                  f"requires_kernel_header = true\n# 1 = BootShim paints progress bands into the framebuffer (see doc 8.9)\npaint_marker = {val}", 1)
open(p, "w", encoding="utf-8").write(s)
PY
  grep -n 'paint_marker' "$CFG"
}

echo "===== build A: paint_marker = true ====="
setflag true
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-marker.log 2>&1 || { tail -30 /root/k70/build-marker.log; exit 1; }
cp -f Build/vermeerPkg/vermeer-kernel /root/k70/vermeer-kernel-marker
printf 'marker kernel: %s bytes  shim=%s\n' "$(stat -c %s /root/k70/vermeer-kernel-marker)" \
  "$(python3 - <<'PY'
import gzip, io, struct
d = open('/root/k70/vermeer-kernel-marker','rb').read()
g = gzip.GzipFile(fileobj=io.BytesIO(d))
raw = g.read()
# image_size sits in the fake ARM64 header at offset 0x10 (little endian)
img_size = struct.unpack_from('<Q', raw, 0x10)[0]
print(img_size - 0x300000)
PY
)"

echo "===== build B: paint_marker = false (primary) ====="
setflag false
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-primary.log 2>&1 || { tail -30 /root/k70/build-primary.log; exit 1; }
cp -f Build/vermeerPkg/vermeer-kernel /root/k70/vermeer-kernel-primary
cp -f Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd "$OUT/SILICIUM_UEFI.fd"
printf 'primary kernel: %s bytes  FV: %s bytes\n' "$(stat -c %s /root/k70/vermeer-kernel-primary)" \
  "$(stat -c %s $OUT/SILICIUM_UEFI.fd)"

echo "===== pack images ====="
python3 Resources/Scripts/mkbootimg.py --kernel /root/k70/vermeer-kernel-primary \
    --ramdisk Resources/ramdisk --header_version 1 -o "$OUT/Mu-vermeer.img"
python3 Resources/Scripts/mkbootimg.py --kernel /root/k70/vermeer-kernel-primary \
    --ramdisk Resources/ramdisk --header_version 0 -o "$OUT/Mu-vermeer-hdr0.img"
python3 Resources/Scripts/mkbootimg.py --kernel /root/k70/vermeer-kernel-marker \
    --ramdisk Resources/ramdisk --header_version 1 -o "$OUT/Mu-vermeer-marker.img"

cp -f Build/vermeerPkg/DEBUG_CLANGPDB/BUILD_REPORT.TXT "$OUT/BUILD_REPORT.TXT"
cp -f /root/k70/build-primary.log "$OUT/BUILDLOG_vermeerPkg.txt"
cd "$OUT"
sha256sum SILICIUM_UEFI.fd Mu-vermeer.img Mu-vermeer-hdr0.img Mu-vermeer-marker.img \
  vermeer-port-src-20261020.tar.gz MODULES-IN-FD.txt BUILD_REPORT.TXT > SHA256SUMS.txt
cat SHA256SUMS.txt
