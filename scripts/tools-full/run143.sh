#!/usr/bin/env bash
# keys143 = keys142 lineage + patch_usb143.py
#   (a) restore vendor HALIOMMUDxe producer into FV (+ APRIORI order, provider first)
#   (b) 4-byte hardening patch of UsbConfigDxe's broken EFI_ERROR check at 0x3FA8
# usage: bash run143.sh [probe]
#   probe : run the gate/patch chain only (no build) and dump effective state
#   default: full build -> /mnt/d/本地项目-01/_tools/b143.log
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

UCFG_REL="Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"

# ---- build_keys143.sh: rename 142 -> 143, chain patch_usb143.py after acpi142,
#      add binary backup + restore inside the existing restore() trap -------------
python3 - <<'PY'
src = open("build_keys142.sh").read()
src = src.replace("TAG=${1:-keys142}", "TAG=${1:-keys143}")
src = src.replace("keys142", "keys143")

needle = "python3 /mnt/d/本地项目-01/_tools/patch_acpi142.py"
assert needle in src, "patch_acpi142.py not in build_keys142.sh"
src = src.replace(needle, needle + " && python3 /mnt/d/本地项目-01/_tools/patch_usb143.py")

# backup before the restore trap is armed (right next to the other backups)
bak_anchor = 'cp "$PKG/Include/APRIORI.inc" /tmp/APRIORI.inc.bak'
assert bak_anchor in src, "APRIORI backup line not found"
src = src.replace(
    bak_anchor,
    bak_anchor + '\ncp "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi" /tmp/UsbConfigDxe.patched.efi.bak143',
)
rest_anchor = '  cp /tmp/APRIORI.inc.bak "$PKG/Include/APRIORI.inc"'
assert rest_anchor in src, "restore() APRIORI line not found"
src = src.replace(
    rest_anchor,
    rest_anchor + '\n  cp /tmp/UsbConfigDxe.patched.efi.bak143 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"',
)
open("build_keys143.sh", "w").write(src)
PY

sed -e 's/keys142/keys143/g' run_keys142.sh > run_keys143.sh
chmod +x build_keys143.sh run_keys143.sh

echo "--- patch chain in build_keys143.sh ---"
grep -n "patch_" build_keys143.sh
echo "--- counts (usb143/acpi142/usb141 should each be 1; nopmic 0) ---"
echo "usb143:  $(grep -c 'patch_usb143' build_keys143.sh)"
echo "acpi142: $(grep -c 'patch_acpi142' build_keys143.sh)"
echo "usb141:  $(grep -c 'patch_usb141' build_keys143.sh)"
echo "nopmic:  $(grep -c 'patch_nopmic138' build_keys143.sh)"
echo "efi bak/restore lines: $(grep -c 'UsbConfigDxe.patched.efi' build_keys143.sh)"

if [ "$1" = "probe" ]; then
  python3 - <<'PY'
src = open("build_keys143.sh").read()
old = "python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6"
assert old in src, "build command line not found"
new = (
    'echo "=== PROBE DXE.inc HALIOMMU/usb ==="; grep -n "HALIOMMUDxe\\|UsbConfigDxe\\|UsbInitDxe\\|UsbMsdDxe\\|PmicVerStub" "$PKG/Include/DXE.inc"; '
    'echo "=== PROBE APRIORI HALIOMMU/provider/usb ==="; grep -n "HALIOMMUDxe\\|VermeerDtbExtnDxe\\|UsbConfigDxe\\|UsbInitDxe\\|UsbMsdDxe\\|PmicVerStub" "$PKG/Include/APRIORI.inc"; '
    'echo "=== PROBE UsbConfigDxe 0x3fa8 bytes ==="; xxd -s 0x3fa8 -l 8 "$UEFI/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"; '
    'echo "=== PROBE fdf acpi/keyprobe ==="; grep -n "AcpiTableDxe\\|VermeerDtbExtnDxe" "$PKG/vermeer.fdf"; exit 0'
)
open("/tmp/build_keys143_probe.sh", "w").write(src.replace(old, new))
PY
  echo "--- running PROBE (no build) ---"
  bash /tmp/build_keys143_probe.sh > /mnt/d/本地项目-01/_tools/b143_probe.log 2>&1
  echo "probe rc=$?"
  tail -60 /mnt/d/本地项目-01/_tools/b143_probe.log
  echo "--- restore check (efi 0x3fa8 back to original) ---"
  xxd -s 0x3fa8 -l 8 /root/k70/uefi/$UCFG_REL
  exit 0
fi

echo "--- running full build (this takes ~3-4 min) ---"
bash run_keys143.sh > /mnt/d/本地项目-01/_tools/b143.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -30 /mnt/d/本地项目-01/_tools/b143.log
echo "--- efi restored? (expect original B6F80208) ---"
xxd -s 0x3fa8 -l 8 /root/k70/uefi/$UCFG_REL
exit $RC
