#!/usr/bin/env bash
# Re-sync the vendor binary seed into the WSL checkout and compile-test the
# VERMEER_VENDOR_HW = 1 configuration again. Every run reports the first
# genuinely broken reference instead of stopping at the PmicDxe one.
set +e
SRC=/mnt/d/本地项目-01/_k70port_extract/vermeer_binaries
DST=/root/k70/uefi/Binaries/vermeer
echo "=== sync $SRC -> $DST ==="
rsync -a --delete "$SRC/" "$DST/" && echo "sync ok"
ls -l "$DST/QcomPkg/Drivers/PmicDxe/" | tail -5

DSC=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
cp -f "$DSC" /root/k70/vermeer.dsc.bak
sed -i 's/^  VERMEER_VENDOR_HW              = 0/  VERMEER_VENDOR_HW              = 1/' "$DSC"

cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-vendorhw.log 2>&1
rc=$?
echo "===== vendor branch build rc=$rc ====="
grep -nE 'error|ERROR' /root/k70/build-vendorhw.log | head -15
grep -E 'FVMAIN |FVMAIN_COMPACT ' /root/k70/build-vendorhw.log | head -3
grep -E 'Images Verified' /root/k70/build-vendorhw.log | head -2

cp -f /root/k70/vermeer.dsc.bak "$DSC"
echo "===== restored VERMEER_VENDOR_HW ====="
grep -n '^  VERMEER_VENDOR_HW' "$DSC"
