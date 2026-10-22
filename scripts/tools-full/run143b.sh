#!/usr/bin/env bash
# keys143b = FALLBACK: keys143 minus the HALIOMMU restore, keeps only the 4-byte
#            UsbConfigDxe EFI_ERROR hardening patch.
#   use this if keys143 hangs / crashes inside HALIOMMU.dll on hardware.
# usage: bash run143b.sh [probe]
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

export NO_HAL=1

python3 - <<'PY'
src = open("build_keys143.sh").read()
src = src.replace("TAG=${1:-keys143}", "TAG=${1:-keys143b}")
src = src.replace("keys143", "keys143b")
open("build_keys143b.sh", "w").write(src)
PY
sed -e 's/keys143/keys143b/g' run_keys143.sh > run_keys143b.sh
chmod +x build_keys143b.sh run_keys143b.sh

echo "--- patch chain (NO_HAL=1: no HALIOMMU uncomment) ---"
grep -n "patch_usb143\|patch_acpi142\|patch_fat137" build_keys143b.sh
echo "nopmic count (0 expected): $(grep -c 'patch_nopmic138' build_keys143b.sh)"

if [ "$1" = "probe" ]; then
  python3 - <<'PY'
src = open("build_keys143b.sh").read()
old = "python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6"
assert old in src
new = ('echo "=== PROBE DXE HALIOMMU (expect keys70-hard) ==="; grep -n "HALIOMMUDxe" "$PKG/Include/DXE.inc"; '
       'echo "=== PROBE APRIORI HALIOMMU ==="; grep -n "HALIOMMUDxe" "$PKG/Include/APRIORI.inc"; '
       'echo "=== PROBE UsbConfigDxe 0x3fa8 (expect 36F80208 here) ==="; xxd -s 0x3fa8 -l 8 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"; exit 0')
open("/tmp/build_keys143b_probe.sh", "w").write(src.replace(old, new))
PY
  bash /tmp/build_keys143b_probe.sh > /mnt/d/本地项目-01/_tools/b143b_probe.log 2>&1
  echo "probe rc=$?"
  tail -40 /mnt/d/本地项目-01/_tools/b143b_probe.log
  echo "--- restored? (expect B6F80208) ---"
  xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
  exit 0
fi

echo "--- running full build (this takes ~3-4 min) ---"
bash run_keys143b.sh > /mnt/d/本地项目-01/_tools/b143b.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -25 /mnt/d/本地项目-01/_tools/b143b.log
echo "--- efi restored? (expect B6F80208) ---"
xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
exit $RC
