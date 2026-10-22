set +e
cd /root/k70/uefi
echo "=== SimpleFbDxe references in fdf/dsc/inc files ==="
grep -rn "SimpleFbDxe" --include="*.fdf" --include="*.inc" --include="*.dsc" --include="*.dsc.inc" . 2>/dev/null | grep -v "^./Build" | head -20
echo "=== vermeer.fdf includes ==="
grep -n "!include" Platforms/Xiaomi/vermeerPkg/vermeer.fdf | head -20