#!/bin/bash
cd /root/k70/uefi || exit 1
echo "=== which vendor .efi contains the 'Memory Allocation' print ==="
for f in Binaries/vermeer/QcomPkg/Drivers/*/*.efi; do
  if strings -a "$f" 2>/dev/null | grep -q "Memory Allocation 0x"; then echo "HIT: $f"; fi
done | head
echo
echo "=== exact format strings around it ==="
for f in Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/*.efi Binaries/vermeer/QcomPkg/Drivers/SmemDxe/*.efi Binaries/vermeer/QcomPkg/Drivers/DALSYSDxe/*.efi; do
  [ -f "$f" ] || continue
  echo "--- $f"
  strings -a "$f" | grep -n "Memory Allocation\|Allocation 0x\|ASSERT %a" | head -5
done
