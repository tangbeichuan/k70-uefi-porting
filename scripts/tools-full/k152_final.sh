#!/bin/bash
# k152_final.sh -- final offline verification of keys152 / keys153
set -u
cd /mnt/d/本地项目-01
W=/mnt/d/本地项目-01
Q=$W/_k70port_extract/qemu-fw
K=$W/K70-UEFI-build
MENU=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
MED=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG/VermeerMenuDxe.efi

echo "=== 1. Menu source: write operations must be gone ==="
for pat in 'Usb150Wr (' 'PRTCAPDIR' 'RUN_STOP' 'DCTL' 'GCTL' 'QSCRATCH' 'ForceLoadSimpleFb' 'LoadImage'; do
  printf '  %-22s count=%s\n' "$pat" "$(grep -c -- "$pat" "$MENU")"
done
echo "  Usb152Diag count=$(grep -c 'Usb152Diag' "$MENU")"
echo "  Usb150Dump count=$(grep -c 'Usb150Dump' "$MENU")"

echo "=== 2. built Menu EFI markers ==="
ls -l "$MED" 2>/dev/null
if [ -f "$MED" ]; then
  for m in MENU152 USB152 UI152 'diag done'; do
    echo "  utf16 '$m' count=$(strings -el "$MED" | grep -c -- "$m")"
  done
  echo "  utf16 'CpuDeadLoop' count=$(strings -el "$MED" | grep -c 'CpuDeadLoop')"
  echo "  ascii '[', count=$(strings "$MED" | grep -c 'USBDIAG')"
fi

echo "=== 3. artifacts ==="
sha256sum "$Q/SILICIUM_UEFI-keys152.fd" "$Q/SILICIUM_UEFI-keys149.fd" "$Q/SILICIUM_UEFI-keys153.fd"
sha256sum "$K/Mu-vermeer-keys152.img" "$K/K70-keys152-MINIMAL-MENU.img" "$K/Mu-vermeer-keys153.img" "$K/K70-keys153-REPACK-BASELINE.img"
ls -l "$K/Mu-vermeer-keys152.img" "$K/Mu-vermeer-keys153.img"

echo "=== 4. boot image structure (keys152) ==="
python3 "$W/_tools/k151_bootimg.py" "$K/Mu-vermeer-keys152.img" 2>&1 | head -20
echo "=== 5. module diff keys149 vs keys152 ==="
python3 "$W/_tools/k151_cmp.py" "$Q/SILICIUM_UEFI-keys149.fd" "$Q/SILICIUM_UEFI-keys152.fd" 2>&1 | tail -8

echo "=== 6. PEI sha (expect keys149 cfcfca5e) ==="
python3 "$W/_tools/k151_struct.py" "$Q/SILICIUM_UEFI-keys152.fd" 2>&1 | head -12

echo "=== 7. Guid.xref present? ==="
ls -l "$W/_tools/guid-keys152.xref" 2>/dev/null && grep -c "" "$W/_tools/guid-keys152.xref"
echo "=== DONE ==="
