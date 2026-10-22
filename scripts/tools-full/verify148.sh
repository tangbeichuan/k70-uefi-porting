#!/bin/bash
# keys148 verification: DWC3 register-map fix in the provider + late RUN_STOP in LogDisk.
set -u
TAG=keys148
TOOLS=/mnt/d/本地项目-01/_tools
KF=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
FD=$KF/qemu-fw/SILICIUM_UEFI-$TAG.fd
IMG=/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-$TAG.img
OUT=/mnt/d/本地项目-01/K70-UEFI-build/K70-$TAG-DWC3-FIX.img
fail=0
ok(){ echo "  OK: $*"; }
bad(){ echo "  FAIL: $*"; fail=1; }

echo "=== artifacts ==="
cp -f "$IMG" "$OUT"
sha256sum "$FD" "$IMG" "$OUT"
ls -l "$FD" "$IMG" "$OUT"

echo "=== DTB payload identical? ==="
python3 $TOOLS/cf146d.py "$FD" > /tmp/k148_fd.txt 2>&1
sha=$(sha256sum $KF/../k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb 2>/dev/null | cut -d' ' -f1)
echo "  xbl_ufs.dtb sha256=$sha"
grep -aE 'DTB|dtb' /tmp/k148_fd.txt | head -5

echo "=== UsbConfigDxe patches present in FV? ==="
grep -aE 'UsbConfigDxe|0x3fa8|0x53cc' /tmp/k148_fd.txt | head -10

echo "=== keys148 provider/LogDisk strings in FD ==="
for s in 'GSNPSID=' '[VBUS] dec' 'phy_susphy' '[USBDIAG] DWC3[' 'DWC3 late run' 'UsbDiagEnsureRun'; do
  n=$(grep -ac -- "$s" "$FD" 2>/dev/null)
  if [ "${n:-0}" -gt 0 ] 2>/dev/null; then ok "FD contains '$s' ($n)"; else bad "FD missing '$s'"; fi
done

echo "=== Guid.xref essential modules ==="
for g in 'CD823A4D' '0A134F0E' '5AF77F10' '94F8A6A7' '9A00771F' '4DB5DEA6' '9622E42C' '5776232E' '5B21E7C4' '9C5E7A31' '4F7A1C2E'; do
  if grep -qi "^$g" "$B/FV/Guid.xref"; then ok "Guid.xref $g"; else bad "Guid.xref missing $g"; fi
done
grep -qi 'UFSDxe' "$B/FV/Guid.xref" && bad "UFSDxe present" || ok "no UFSDxe"

echo "=== LogDisk EFI size (was 22528 in keys147d) ==="
LD=$(find "$B/AARCH64" -name VermeerLogDiskDxe.efi | head -1)
ls -l "$LD"
grep -ac 'DWC3 late run' "$LD" >/dev/null && ok "LogDisk contains late-run code"
DT=$(find "$B/AARCH64" -name VermeerDtbExtnDxe.efi | head -1)
ls -l "$DT"
grep -ac 'phy_susphy' "$DT" >/dev/null && ok "DtbExtn contains keys148 dump"

echo "=== FVMAIN.Fv module placement ==="
grep -nE 'UsbConfigDxe|UsbInitDxe|UsbMsdDxe|HALIOMMUDxe|ClockDxe|AcpiTableDxe' "$B/FV/FVMAIN.inf" | head -12

echo "=== restore check (source tree pristine) ==="
grep -n 'UsbConfigDxe' "$KF/../k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.inf" >/dev/null 2>&1
python3 - <<'EOF'
data = open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi','rb').read()
print("  UsbConfigDxe.patched.efi 0x3fa8 =", data[0x3fa8:0x3fac].hex(), "0x53cc =", data[0x53cc:0x53d0].hex())
EOF

echo "=== RESULT: $([ $fail -eq 0 ] && echo PASS || echo FAIL) ==="
exit $fail
