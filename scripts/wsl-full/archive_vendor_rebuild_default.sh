#!/usr/bin/env bash
# Archive the vendor-hardware FV (built with VERMEER_VENDOR_HW=1 just to prove
# the stage-U7 configuration compiles), then rebuild the default Mu-only image
# so the published artifacts are the ones that should actually be flashed.
set +e
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
OUT=/mnt/d/本地项目-01/K70-UEFI-build

echo "=== archive vendor-hardware FV (reference only, NOT for flashing) ==="
cp -f "$FV/SILICIUM_UEFI.fd" "$OUT/SILICIUM_UEFI-vendorhw-DO-NOT-FLASH.fd" && ls -l "$OUT/SILICIUM_UEFI-vendorhw-DO-NOT-FLASH.fd"
cp -f /root/k70/build-vendorhw.log "$OUT/BUILDLOG_vendorhw.txt"
grep -E 'FVMAIN \[|FVMAIN_COMPACT \[' /root/k70/build-vendorhw.log | sed 's/^INFO - //' > "$OUT/VENDORHW-FV-SPACE.txt"
cat "$OUT/VENDORHW-FV-SPACE.txt"

echo
echo "=== rebuild default (Mu-only, VERMEER_VENDOR_HW=0) ==="
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-default.log 2>&1
echo "rc=$?"
grep -E 'FVMAIN \[|FVMAIN_COMPACT \[|Images Verified' /root/k70/build-default.log | sed 's/^INFO - //'
sha256sum "$FV/SILICIUM_UEFI.fd"
ls -l /root/k70/uefi/Mu-vermeer.img 2>/dev/null | tail -1
