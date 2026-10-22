#!/usr/bin/env bash
# keys142 = keys141 lineage + patch_acpi142.py (enable AcpiTableDxe => gEfiAcpiSdtProtocolGuid).
#   usage: bash run142.sh [probe]
#   probe  : run the gates/patch chain only (no build), dump effective ACPI/DXE state
#   default: full build -> /mnt/d/本地项目-01/_tools/b142.log
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

# build: rename 141 -> 142, chain patch_acpi142.py after patch_usb141.py
python3 - <<'PY'
src = open("build_keys141.sh").read()
src = src.replace("keys141", "keys142")
src = src.replace("keys140", "keys142")
needle = "python3 /mnt/d/本地项目-01/_tools/patch_usb141.py"
assert needle in src, "patch_usb141.py not in build_keys141.sh"
src = src.replace(needle, needle + " && python3 /mnt/d/本地项目-01/_tools/patch_acpi142.py")
open("build_keys142.sh", "w").write(src)
PY

sed -e 's/keys141/keys142/g' run_keys141.sh > run_keys142.sh
chmod +x build_keys142.sh run_keys142.sh

echo "--- patch chain in build_keys142.sh ---"
grep -n "patch_" build_keys142.sh
echo "--- nopmic count (should be 0) ---"
grep -c "patch_nopmic138" build_keys142.sh
echo "--- usb141 count (should be 1) ---"
grep -c "patch_usb141" build_keys142.sh
echo "--- acpi142 count (should be 1) ---"
grep -c "patch_acpi142" build_keys142.sh

if [ "$1" = "probe" ]; then
  python3 - <<'PY'
src = open("build_keys142.sh").read()
old = "python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6"
assert old in src, "build command line not found"
new = (
    'echo "=== PROBE fdf ACPI block ==="; grep -n "Acpi" vermeer.fdf; '
    'echo "=== PROBE DXE.inc usb/pmic ==="; grep -n "UsbConfigDxe\\|UsbInitDxe\\|UsbMsdDxe\\|PmicVerStub\\|PmicDxeLa" Include/DXE.inc; '
    'echo "=== PROBE APRIORI usb/pmic ==="; grep -n "UsbConfigDxe\\|UsbInitDxe\\|UsbMsdDxe\\|PmicVerStub" Include/APRIORI.inc; '
    'echo "=== PROBE fdf banner/DTB ==="; grep -n "FILE FREEFORM\\|DtPlatform\\|Extra.fdf" vermeer.fdf; exit 0'
)
open("/tmp/build_keys142_probe.sh", "w").write(src.replace(old, new))
PY
  echo "--- running PROBE (no build) ---"
  bash /tmp/build_keys142_probe.sh > /mnt/d/本地项目-01/_tools/b142_probe.log 2>&1
  echo "probe rc=$?"
  tail -80 /mnt/d/本地项目-01/_tools/b142_probe.log
  exit 0
fi

echo "--- running full build (this takes ~3-4 min) ---"
bash run_keys142.sh > /mnt/d/本地项目-01/_tools/b142.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -30 /mnt/d/本地项目-01/_tools/b142.log
exit $RC
