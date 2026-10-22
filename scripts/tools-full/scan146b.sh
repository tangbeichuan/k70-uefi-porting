#!/bin/bash
# scan146b.sh -- find which FV module could fault at RVA 0x3FF0 with FAR=8
# (ELR=0xC64E0FF0, base assumed page-aligned). UsbConfigDxe is one candidate;
# check every prebuilt QcomPkg driver (Binaries tree) + report its 0x3FF0 instr.
set -u
OUT=/mnt/d/本地项目-01/_tools/scan146b.log
: > "$OUT"
echo "=== drivers whose 0x3FF0 instruction is ldr xN,[xN,#0x8] ===" | tee -a "$OUT"
for f in $(find /root/k70/uefi/Binaries/vermeer -name "*.efi" | sort); do
  ins=$(llvm-objdump -d --start-address=0x3ff0 --stop-address=0x3ff4 "$f" 2>/dev/null | awk '/^ *3ff0:/')
  case "$ins" in
    *"ldr	x8, [x8, #0x8]"*|*"ldr	x0, [x0, #0x8]"*|*"ldr	x9, [x9, #0x8]"*|*"ldr	x1, [x1, #0x8]"*)
      echo "HIT $f :: $ins" | tee -a "$OUT" ;;
  esac
done
echo
echo "=== USB / clock / iommu drivers: window 0x3FE0-0x4000 ===" | tee -a "$OUT"
for m in UsbConfigDxe UsbInitDxe UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbBusDxe UsbPwrCtrlDxe ClockDxe HALIOMMUDxe; do
  f=$(find /root/k70/uefi/Binaries/vermeer -name "$m.patched.efi" -o -name "$m.efi" | head -1)
  [ -z "$f" ] && { echo "MISSING $m" | tee -a "$OUT"; continue; }
  echo "----- $m : $f" | tee -a "$OUT"
  llvm-objdump -d --start-address=0x3fe0 --stop-address=0x4000 "$f" 2>/dev/null | grep -E "^ *3f|^ *40" | tee -a "$OUT"
done
echo
echo "=== also scan 0xFF0, 0x1FF0, 0x2FF0, 0x4FF0, 0x5FF0 for ldr x8,[x8,#8] in USB modules ===" | tee -a "$OUT"
for m in UsbConfigDxe UsbInitDxe UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe ClockDxe HALIOMMUDxe; do
  f=$(find /root/k70/uefi/Binaries/vermeer -name "$m.patched.efi" -o -name "$m.efi" | head -1)
  [ -z "$f" ] && continue
  for rva in 0xff0 0x1ff0 0x2ff0 0x4ff0 0x5ff0 0x6ff0; do
    ins=$(llvm-objdump -d --start-address=$rva --stop-address=$(printf '0x%x' $((rva+4))) "$f" 2>/dev/null | awk -v r=$(printf '%x' $rva) '$1==r":"')
    [ -n "$ins" ] && echo "  $m @$rva: $ins" | tee -a "$OUT"
  done
done
echo "done -> $OUT"
