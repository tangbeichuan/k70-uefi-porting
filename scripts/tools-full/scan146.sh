#!/bin/bash
# scan146.sh -- which built module has `ldr x8,[x8,#0x8]` exactly at RVA 0x3FF0
# (the keys144 crash ELR=0xC64E0FF0 with a page-aligned base 0xC64DD000 -> RVA 0x3FF0)?
set -u
OUT=/mnt/d/本地项目-01/_tools/scan146.log
: > "$OUT"
for f in /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/*.efi; do
  d=$(llvm-objdump -d --start-address=0x3fe0 --stop-address=0x3ff8 "$f" 2>/dev/null \
      | grep -E "^\s+3ff0:" )
  case "$d" in
    *"ldr	x8, [x8, #0x8]"*|*"ldr	x8, [x8, #8]"*)
      echo "HIT $(basename "$f") :: $d" | tee -a "$OUT" ;;
  esac
done
echo "---"; echo "hits: $(grep -c HIT "$OUT" 2>/dev/null || true)"
echo "===== all modules with ldr x8,[x8,#8] at 0x3ff0 listed above ====="
# also: the 6 candidate USB/IOMMU modules, full window 0x3fe8-0x4000
for m in UsbConfigDxe ClockDxe UsbInitDxe UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe HALIOMMUDxe AcpiTableDxe; do
  f=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/$m.efi
  [ -f "$f" ] || { echo "MISSING $m.efi"; continue; }
  echo "===== $m 0x3fe0-0x4000 ====="
  llvm-objdump -d --start-address=0x3fe0 --stop-address=0x4000 "$f" 2>/dev/null | grep -E "^\s+3f|^\s+40" | head -12
  echo "  0x3ff0 bytes: $(xxd -s 0x3ff0 -l 4 -p "$f")"
done