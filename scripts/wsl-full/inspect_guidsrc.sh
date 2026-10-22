#!/usr/bin/env bash
# Find what protocol ae37b942-457f-4c91-a196-d9669fd347a3 is, and check which vendor
# INF files point their PE32 image at the patched binary.
set +e
echo "=== source tree references to the GUID ==="
grep -rils "AE37B942" /root/k70/uefi 2>/dev/null | head -20

echo
echo "=== INF PE32 / BASE_NAME lines ==="
for d in SPMIDxe PmicDxe TLMMDxe ButtonsDxe PmicGlinkDxe DALSYSDxe RpmhDxe VcsDxe; do
  for f in /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/"$d"/*.inf; do
    [ -f "$f" ] || continue
    echo "== $f"
    grep -n "BASE_NAME\|PE32\|UI \|LIBRARY_CLASS\|MODULE_TYPE" "$f" | head -6
  done
done

echo
echo "=== which patched binaries exist for the input set ==="
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/{SPMIDxe,PmicDxe,TLMMDxe,ButtonsDxe}/*.efi 2>/dev/null
