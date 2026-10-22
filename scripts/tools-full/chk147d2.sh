#!/usr/bin/env bash
set -u
cd /root/k70/uefi
B=Build/vermeerPkg/DEBUG_CLANGPDB
OUT=/mnt/d/本地项目-01/K70-UEFI-build
QV=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
echo "=== artifact shas ==="
sha256sum "$QV/SILICIUM_UEFI-keys147d.fd" "$OUT/Mu-vermeer-keys147d.img" 2>/dev/null
ls -l --time-style=+%H:%M:%S "$QV/SILICIUM_UEFI-keys147d.fd" "$OUT/Mu-vermeer-keys147d.img" 2>/dev/null
echo "=== diag strings in LogDisk EFI ==="
LOGD="$B/AARCH64/VermeerLogDiskDxe.efi"
ls -l --time-style=+%H:%M:%S "$LOGD" 2>/dev/null
for pat in 'USBDIAG' 'LocateProtocol(UsbFnIo)' 'iface+0x88' 'ConnectController' 'DWC3 GCTL' 'probe timer arm'; do
  grep -aq "$pat" "$LOGD" && echo "  OK: $pat" || echo "  MISSING: $pat"
done
echo "=== diag strings in FVMAIN.Fv ==="
for pat in 'USBDIAG' 'LocateProtocol(UsbFnIo)' 'iface+0x88' 'probe timer arm'; do
  grep -aq "$pat" "$B/FV/FVMAIN.Fv" && echo "  OK: $pat" || echo "  MISSING: $pat"
done
echo "=== FVMAIN.Fv size / VBUS / dtb ==="
stat -c '%n %s %y' "$B/FV/FVMAIN.Fv"
python3 - <<'PY'
import hashlib, pathlib
dtb = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb').read_bytes()
fv  = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv').read_bytes()
print('  dtb sha256:', hashlib.sha256(dtb).hexdigest()[:32], len(dtb), 'B; copies in FV:', fv.count(dtb))
print('  vbus strings in FV:', fv.count(b'[VBUS] before:'))
print('  USBDIAG in FV:', fv.count(b'USBDIAG'))
PY
echo "=== Guid.xref: expected modules ==="
for pat in VermeerLogDiskDxe VermeerDtbExtnDxe UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe UsbDeviceDxe PmicDxe AcpiTableDxe ClockDxe HALIOMMU VermeerPmicVerStubDxe; do
  grep -qi "$pat" "$B/FV/Guid.xref" && echo "  OK: $pat" || echo "  MISSING: $pat"
done
grep -i 'UFSDxe' "$B/FV/Guid.xref" && echo "  UNEXPECTED UFSDxe" || echo "  OK: no UFSDxe"
echo "=== LogDisk FFS inside FV (payload cmp) ==="
python3 - <<'PY'
import pathlib
fv = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv').read_bytes()
eff = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerLogDiskDxe.efi').read_bytes()
print('  logdisk efi sha:', __import__('hashlib').sha256(eff).hexdigest()[:24], len(eff), 'B')
print('  payload copies in FV:', fv.count(eff))
PY
echo "=== UsbConfigDxe patch bytes inside FV ==="
python3 - <<'PY'
import pathlib, struct
p = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/UsbConfigDxe.efi')
print('  built UsbConfigDxe.efi size:', p.stat().st_size)
PY
python3 /mnt/d/本地项目-01/_tools/cf146d.py 2>&1 | tail -6
