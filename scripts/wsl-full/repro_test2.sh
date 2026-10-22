#!/usr/bin/env bash
# Is the toolchain reproducible here? Repack the same kernel, then do a clean rebuild
# and compare (a) image shas and (b) FV sha.
set -e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
OUT=/mnt/d/本地项目-01/K70-UEFI-build

echo "== 1. repack the same staged kernel =="
python3 Resources/Scripts/mkbootimg.py --kernel /root/k70/vermeer-kernel-primary \
    --ramdisk Resources/ramdisk --header_version 1 -o /root/k70/repack.img
sha256sum /root/k70/repack.img | sed 's/^/  repack  /'
sha256sum "$OUT/Mu-vermeer.img" | sed 's/^/  shipped /'
cmp -s /root/k70/repack.img "$OUT/Mu-vermeer.img" && echo "  => pack is deterministic" || echo "  => pack differs"

echo "== 2. clean rebuild from scratch =="
sha_before=$(sha256sum Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd | cut -d' ' -f1)
rm -rf Build/vermeerPkg
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-clean3.log 2>&1 || { tail -20 /root/k70/build-clean3.log; exit 1; }
sha_after=$(sha256sum Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd | cut -d' ' -f1)
echo "  before: $sha_before"
echo "  after : $sha_after"
if [ "$sha_before" = "$sha_after" ]; then
  echo "  => FV build is bit-reproducible"
else
  echo "  => FV build differs; byte diff count: $(cmp -l Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd /dev/null 2>/dev/null | wc -l)"
fi
