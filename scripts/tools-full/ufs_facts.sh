#!/usr/bin/env bash
# Gathers the facts needed for the UFS work that is queued behind the input experiment.
U=/root/k70/uefi
echo "=== vendor drivers whose name mentions ufs/storage/pmic/iommu ==="
ls "$U/Binaries/vermeer/QcomPkg/Drivers" | grep -iE 'ufs|storage|pmic|iommu|ice' || true
echo
echo "=== does vermeer.dtb carry the ufs nodes UFSDxe looks for? ==="
for p in 'ufs' 'ufshc' 'init_speed_params' 'perf_speed_params' 'timeout_values' 'ufs0_vcc' 'vccq'; do
  n=$(strings -a "$U/Resources/DTBs/vermeer.dtb" 2>/dev/null | grep -c -i -- "$p" || true)
  printf '  %-22s %s\n' "$p" "${n:-0}"
done
echo
echo "=== the ufs-related DT strings actually present ==="
strings -a "$U/Resources/DTBs/vermeer.dtb" 2>/dev/null | grep -iE 'ufs|ufshc' | sort -u | head -25
echo
echo "=== is there a UfsCoreBspLib anywhere in the Mu tree (source, not binary)? ==="
grep -ril 'UfsCoreBspLib' "$U" --include=*.inf --include=*.c --include=*.h 2>/dev/null | head
echo
echo "=== UFSDxe.inf depex + protocols ==="
sed -n '1,200p' "$U/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.inf" | grep -iE 'Depex|Protocol|Pcd|LibraryClasses|^\[' | head -40
