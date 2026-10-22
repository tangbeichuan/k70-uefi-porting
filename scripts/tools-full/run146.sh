#!/usr/bin/env bash
# keys146 = keys145 lineage (ClockDxe + HALIOMMU + 0x53CC teardown guard)
#   PLUS patch_usb146.py: UsbConfigDxe 0x3FA8 becomes an unconditional jump to
#   the vendor "IOMMU unavailable" branch (0x3FB0).  This is the real fix for
#   the keys143/144/145 EFI_ERROR bug: 'mov w8,w0' zero-extends EFI status, so
#   testing bit31/bit63 of w8 never detects EFI_NOT_FOUND (0x0E) nor any other
#   status whose low 32 bits have bit31 clear.  Taking the vendor fallback
#   bypasses the corrupt/unexpected HAL IOMMU interface pointer that produced
#   the keys145 "transact" jump, and keeps every later IOMMU user disabled via
#   the flag bytes at .data 0x13780/0x13781.
# usage: bash run146.sh [probe]
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

python3 - <<'PY'
src = open("build_keys145.sh").read()
src = src.replace("keys145", "keys146")
old = "python3 /mnt/d/本地项目-01/_tools/patch_fat137.py"
new = ("python3 /mnt/d/本地项目-01/_tools/patch_usb146.py && "
       "python3 /mnt/d/本地项目-01/_tools/patch_fat137.py")
assert old in src and "patch_usb146" not in src, "unexpected build_keys145.sh shape"
src = src.replace(old, new)
for needle in ["UsbConfigDxe.patched.efi.bak143", "UsbConfigDxe.patched.efi"]:
    assert needle in src, "missing restore-trap reference: " + needle
open("build_keys146.sh", "w").write(src)
PY
sed -e 's/keys145/keys146/g' run_keys145.sh > run_keys146.sh
chmod +x build_keys146.sh run_keys146.sh

echo "--- keys146 lineage ---"
grep -n "TAG=" build_keys146.sh | head -2
echo "--- patch chain ---"
grep -n "patch_usb143\|patch_clock144\|patch_usb145\|patch_usb146\|patch_fat137" build_keys146.sh
echo "nopmic count (0 expected): $(grep -c 'patch_nopmic138' build_keys146.sh)"
echo "NO_HAL count in build script (0 expected): $(grep -c 'NO_HAL' build_keys146.sh)"
echo "backup trap count (2 expected): $(grep -c 'UsbConfigDxe.patched.efi.bak143' build_keys146.sh)"

if [ "$1" = "probe" ]; then
  python3 - <<'PY'
src = open("build_keys146.sh").read()
old = "python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6"
assert old in src
new = ('echo "=== PROBE DXE.inc HALIOMMU/ClockDxe (expect active) ==="; grep -n "HALIOMMUDxe\\|ClockDxe" "$PKG/Include/DXE.inc"; '
       'echo "=== PROBE APRIORI order ==="; grep -n "HALIOMMUDxe\\|VermeerDtbExtnDxe\\|ClockDxe\\|UsbConfigDxe\\|VermeerPmicVerStubDxe\\|UsbInitDxe\\|UsbMsdDxe" "$PKG/Include/APRIORI.inc"; '
       'echo "=== PROBE UsbConfigDxe bytes (expect 3fa8=02000014 53cc=280100b4) ==="; xxd -s 0x3fa8 -l 8 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"; xxd -s 0x53cc -l 16 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"; exit 0')
open("/tmp/build_keys146_probe.sh", "w").write(src.replace(old, new))
PY
  bash /tmp/build_keys146_probe.sh > /mnt/d/本地项目-01/_tools/b146_probe.log 2>&1
  echo "probe rc=$?"
  tail -50 /mnt/d/本地项目-01/_tools/b146_probe.log
  echo "--- restored? (expect b6f80208 at 0x3fa8, 080540f9 at 0x53cc) ---"
  xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
  xxd -s 0x53cc -l 16 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
  exit 0
fi

echo "--- running full build (this takes ~3-4 min) ---"
bash run_keys146.sh > /mnt/d/本地项目-01/_tools/b146.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -30 /mnt/d/本地项目-01/_tools/b146.log
echo "--- efi restored? ---"
xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
xxd -s 0x53cc -l 16 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
exit $RC
