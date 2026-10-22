#!/usr/bin/env bash
# Compile-test the vendor-hardware branch (VERMEER_VENDOR_HW = 1). This is the
# U7 configuration; doing it now shows what is still missing instead of finding
# out months later. The DSC is restored afterwards regardless of the result.
set +e
DSC=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
cp -f "$DSC" /root/k70/vermeer.dsc.bak
sed -i 's/^  VERMEER_VENDOR_HW              = 0/  VERMEER_VENDOR_HW              = 1/' "$DSC"
grep -n 'VERMEER_VENDOR_HW' "$DSC" | head -3

cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-vendorhw.log 2>&1
rc=$?
echo "===== vendor branch build rc=$rc ====="
grep -nE 'error|Error|ERROR' /root/k70/build-vendorhw.log | grep -vE '^[0-9]+:INFO - (Pcd|No )' | head -20
echo "--- FV size line ---"
grep -E 'FVMAIN|FVMAIN_COMPACT|FV Space' /root/k70/build-vendorhw.log | head -4

cp -f /root/k70/vermeer.dsc.bak "$DSC"
echo "===== restored ====="
grep -n '^  VERMEER_VENDOR_HW' "$DSC"
