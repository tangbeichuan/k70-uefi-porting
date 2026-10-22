#!/usr/bin/env bash
set +e
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
BFV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
echo "=== PmicDxe module in build tree ==="
PE=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64 -name 'PmicDxe*.efi' 2>/dev/null | head -3)
echo "$PE"
for f in $PE; do sha256sum "$f"; done
echo "=== vendor stock PmicDxeLa.efi ==="
sha256sum /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi
echo "=== FVMAIN.inf PmicDxe line ==="
grep -i "PmicDxe" "$BFV/FVMAIN.inf" | head -5
echo "=== xref: keys139 vs keys140 PmicDxe ==="
echo -n "keys139 xref: "; grep -ic "PmicDxe" /tmp/guid-keys139.xref
echo -n "keys140 xref: "; grep -ic "PmicDxe" /tmp/guid-keys140.xref
echo "=== FV blob: provider banner + PmicDxe binary marker ==="
for pat in "vermeer dtb-extn provider" "PmicDxe" "spmi-vadc@7"; do
  echo -n "  [$pat] in FVMAIN.Fv: "; grep -ac "$pat" "$BFV/FVMAIN.Fv"
done
echo "=== the DTBExtn FILE FREEFORM (7E5B1C3A) in FV ==="
grep -ac "7E5B1C3A" "$BFV/FVMAIN.inf"
echo "=== keys139/140 Guid.xref diff summary ==="
diff <(sort /tmp/guid-keys139.xref) <(sort /tmp/guid-keys140.xref) | head -20
echo "=== build log tails ==="
echo "--- keys139 ---"; tail -6 /tmp/keys139-build.log
echo "--- keys140 ---"; tail -6 /tmp/keys140-build.log
