#!/usr/bin/env bash
# keys141 = keys140 lineage + patch_usb141.py (UsbConfigDxe into FV + dispatch order).
#   usage: bash run141.sh [probe]
#   probe  : run the gates/patch chain only (no build), dump effective DXE/APRIORI state
#   default: full build -> /mnt/d/本地项目-01/_tools/b141.log
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

# build: rename 140 -> 141, chain patch_usb141.py after patch_pmicstub127.py
python3 - <<'PY'
import re
src = open("build_keys140.sh").read()
src = src.replace("keys140", "keys141")
# keep the real PMIC driver (no nopmic patch)
src = src.replace(" && python3 /mnt/d/本地项目-01/_tools/patch_nopmic138.py", "")
needle = "python3 /mnt/d/本地项目-01/_tools/patch_pmicstub127.py"
assert needle in src, "patch_pmicstub127.py not in build_keys140.sh"
src = src.replace(needle, needle + " && python3 /mnt/d/本地项目-01/_tools/patch_usb141.py")
open("build_keys141.sh", "w").write(src)
PY

sed -e 's/keys140/keys141/g' run_keys140.sh > run_keys141.sh
chmod +x build_keys141.sh run_keys141.sh

echo "--- patch chain in build_keys141.sh ---"
grep -n "patch_" build_keys141.sh
echo "--- nopmic count (should be 0) ---"
grep -c "patch_nopmic138" build_keys141.sh
echo "--- usb141 count (should be 1) ---"
grep -c "patch_usb141" build_keys141.sh

if [ "$1" = "probe" ]; then
  python3 - <<'PY'
src = open("build_keys141.sh").read()
old = "python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6"
assert old in src, "build command line not found"
new = (
    'echo "=== PROBE DXE.inc ==="; grep -n "UsbConfigDxe\\|UsbInitDxe\\|UsbMsdDxe\\|PmicVerStub" Include/DXE.inc; '
    'echo "=== PROBE APRIORI.inc ==="; grep -n "UsbConfigDxe\\|UsbInitDxe\\|UsbMsdDxe\\|PmicVerStub" Include/APRIORI.inc; '
    'echo "=== PROBE dsc gates ==="; grep -n "VERMEER_VENDOR_HW\\|VERMEER_VENDOR_INPUT" vermeer.dsc | head -6; '
    'echo "=== PROBE fdf includes ==="; grep -n "DXE.inc\\|APRIORI.inc" vermeer.fdf; exit 0'
)
open("/tmp/build_keys141_probe.sh", "w").write(src.replace(old, new))
PY
  echo "--- running PROBE (no build) ---"
  bash /tmp/build_keys141_probe.sh > /mnt/d/本地项目-01/_tools/b141_probe.log 2>&1
  echo "probe rc=$?"
  tail -60 /mnt/d/本地项目-01/_tools/b141_probe.log
  exit 0
fi

echo "--- running full build (this takes ~3-4 min) ---"
bash run_keys141.sh > /mnt/d/本地项目-01/_tools/b141.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -30 /mnt/d/本地项目-01/_tools/b141.log
exit $RC
