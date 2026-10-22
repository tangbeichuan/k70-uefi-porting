#!/usr/bin/env bash
# Prove that keys13a really has ULogDxe and keys13b really has no NpaDxe,
# by looking for the driver's own PE strings inside each FD.
Q=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
for fd in SILICIUM_UEFI-keys12.fd SILICIUM_UEFI-keys13a.fd SILICIUM_UEFI-keys13b.fd; do
  f="$Q/$fd"
  [ -f "$f" ] || { echo "$fd MISSING"; continue; }
  echo "=== $fd  $(stat -c %s "$f") B"
  # ULogDxe-unique string from its PE, and a NpaDxe-unique one
  for pat in 'ULogDxe.efi' 'LogDxe' 'NpaDxe' 'npa_core' 'NPA' 'Gladiator'; do
    n=$(grep -a -c -- "$pat" "$f" 2>/dev/null || true)
    printf '   %-14s %s\n' "$pat" "${n:-0}"
  done
done
echo
echo "=== last build Guid.xref (this is keys13a) ==="
grep -iE 'ULogDxe|NpaDxe|ButtonsDxe|SPMIDxe|UFSDxe' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref | head -20
