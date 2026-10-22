#!/usr/bin/env bash
# keys144 = keys143b (NO_HAL + UsbConfigDxe EFI_ERROR hardening) PLUS ClockDxe
#           restored into the FV, dispatched BEFORE UsbConfigDxe so that
#           gEfiClockProtocolGuid (241AFAE6-885F-4F6C-A7EA-C28EAB79C3E5) exists.
# fallback keys144b = keys143b image as-is (path/sha must stay untouched).
# usage: bash run144.sh [probe]
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

export NO_HAL=1

python3 - <<'PY'
src = open("build_keys143b.sh").read()
src = src.replace("TAG=${1:-keys143bb}", "TAG=${1:-keys144}")
src = src.replace("TAG=${1:-keys143b}", "TAG=${1:-keys144}")
src = src.replace("keys143b", "keys144")
# insert patch_clock144.py just before patch_fat137.py (which only validates)
old = "python3 /mnt/d/本地项目-01/_tools/patch_fat137.py"
new = ("python3 /mnt/d/本地项目-01/_tools/patch_clock144.py && "
       "python3 /mnt/d/本地项目-01/_tools/patch_fat137.py")
assert old in src and "patch_clock144" not in src, "unexpected build_keys143b.sh shape"
src = src.replace(old, new)
open("build_keys144.sh", "w").write(src)
PY
sed -e 's/keys143b/keys144/g' run_keys143b.sh > run_keys144.sh
chmod +x build_keys144.sh run_keys144.sh

echo "--- keys144 lineage ---"
grep -n "TAG=" build_keys144.sh | head -2
echo "--- patch chain ---"
grep -n "patch_usb143\|patch_acpi142\|patch_clock144\|patch_fat137" build_keys144.sh
echo "nopmic count (0 expected): $(grep -c 'patch_nopmic138' build_keys144.sh)"
echo "NO_HAL exported: ${NO_HAL} (HALIOMMU stays commented out)"

if [ "$1" = "probe" ]; then
  python3 - <<'PY'
src = open("build_keys144.sh").read()
old = "python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6"
assert old in src
new = ('echo "=== PROBE DXE.inc ClockDxe (expect active INF) ==="; grep -n "ClockDxe" "$PKG/Include/DXE.inc"; '
       'echo "=== PROBE APRIORI.inc ClockDxe + UsbConfigDxe order ==="; grep -n "ClockDxe\\|UsbConfigDxe\\|VermeerPmicVerStubDxe" "$PKG/Include/APRIORI.inc"; '
       'echo "=== PROBE HALIOMMU still out (expect 2 x keys70-hard) ==="; grep -n "HALIOMMUDxe" "$PKG/Include/DXE.inc" "$PKG/Include/APRIORI.inc"; '
       'echo "=== PROBE UsbConfigDxe 0x3fa8 (expect 36F80208 here) ==="; xxd -s 0x3fa8 -l 8 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"; exit 0')
open("/tmp/build_keys144_probe.sh", "w").write(src.replace(old, new))
PY
  bash /tmp/build_keys144_probe.sh > /mnt/d/本地项目-01/_tools/b144_probe.log 2>&1
  echo "probe rc=$?"
  tail -40 /mnt/d/本地项目-01/_tools/b144_probe.log
  echo "--- restored? (expect B6F80208) ---"
  xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
  exit 0
fi

echo "--- running full build (this takes ~3-4 min) ---"
bash run_keys144.sh > /mnt/d/本地项目-01/_tools/b144.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -30 /mnt/d/本地项目-01/_tools/b144.log
echo "--- efi restored? (expect B6F80208) ---"
xxd -s 0x3fa8 -l 8 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
exit $RC
