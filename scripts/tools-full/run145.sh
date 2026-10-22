#!/usr/bin/env bash
# keys145 = keys144 (ClockDxe restored, UsbConfigDxe EFI_ERROR hardened,
#           NO_HAL at that time)  PLUS
#   A) HALIOMMUDxe restored into DXE.inc + APRIORI.inc (IOMMU globals non-NULL)
#   B) UsbConfigDxe teardown NULL guard (cbz x8,0x53f0) so a missing IOMMU
#      context can never fault at [x8,#8] (FAR=0x8) again.
# usage: bash run145.sh [probe]
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

python3 - <<'PY'
src = open("build_keys144.sh").read()
src = src.replace("keys144", "keys145")
old = "python3 /mnt/d/本地项目-01/_tools/patch_fat137.py"
new = ("python3 /mnt/d/本地项目-01/_tools/patch_usb145.py && "
       "python3 /mnt/d/本地项目-01/_tools/patch_fat137.py")
assert old in src and "patch_usb145" not in src, "unexpected build_keys144.sh shape"
src = src.replace(old, new)
# make sure the efi backup/restore trap from the keys143 lineage is present
for needle in ["UsbConfigDxe.patched.efi.bak143", "UsbConfigDxe.patched.efi"]:
    assert needle in src, "missing restore-trap reference: " + needle
open("build_keys145.sh", "w").write(src)
PY
sed -e 's/keys144/keys145/g' run_keys144.sh > run_keys145.sh
chmod +x build_keys145.sh run_keys145.sh

echo "--- keys145 lineage ---"
grep -n "TAG=" build_keys145.sh | head -2
echo "--- patch chain ---"
grep -n "patch_usb143\|patch_clock144\|patch_usb145\|patch_fat137" build_keys145.sh
echo "nopmic count (0 expected): $(grep -c 'patch_nopmic138' build_keys145.sh)"
echo "NO_HAL exported: '${NO_HAL:-<unset>}' (HALIOMMU will be restored)"
echo "backup trap count (2 expected): $(grep -c 'UsbConfigDxe.patched.efi.bak143' build_keys145.sh)"

if [ "$1" = "probe" ]; then
  python3 - <<'PY'
src = open("build_keys145.sh").read()
old = "python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6"
assert old in src
new = ('echo "=== PROBE DXE.inc HALIOMMU (expect active) ==="; grep -n "HALIOMMUDxe" "$PKG/Include/DXE.inc"; '
       'echo "=== PROBE APRIORI HALIOMMU + provider + clock/cfg order ==="; grep -n "HALIOMMUDxe\\|VermeerDtbExtnDxe\\|ClockDxe\\|UsbConfigDxe\\|VermeerPmicVerStubDxe\\|UsbInitDxe\\|UsbMsdDxe" "$PKG/Include/APRIORI.inc"; '
       'echo "=== PROBE DXE.inc ClockDxe/UsbConfigDxe/UsbInitDxe ==="; grep -n "ClockDxe\\|UsbConfigDxe\\|UsbInitDxe" "$PKG/Include/DXE.inc"; '
       'echo "=== PROBE UsbConfigDxe bytes 0x3fa8 (expect 36F80208) 0x53cc (expect 280100b4) ==="; xxd -s 0x3fa8 -l 8 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"; xxd -s 0x53cc -l 16 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"; exit 0')
open("/tmp/build_keys145_probe.sh", "w").write(src.replace(old, new))
PY
  bash /tmp/build_keys145_probe.sh > /mnt/d/本地项目-01/_tools/b145_probe.log 2>&1
  echo "probe rc=$?"
  tail -45 /mnt/d/本地项目-01/_tools/b145_probe.log
  echo "--- restored? (expect B6F80208 at 0x3fa8, 080540f9 at 0x53cc) ---"
  xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
  xxd -s 0x53cc -l 16 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
  exit 0
fi

echo "--- running full build (this takes ~3-4 min) ---"
bash run_keys145.sh > /mnt/d/本地项目-01/_tools/b145.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -30 /mnt/d/本地项目-01/_tools/b145.log
echo "--- efi restored? ---"
xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
xxd -s 0x53cc -l 16 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
exit $RC
