set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
echo "=== Guid.xref SimpleFb ==="
grep -i "SimpleFb" "$B/Guid.xref" 2>/dev/null
echo "=== FVMAIN.Fv.txt DCFD1E6D ==="
grep -i "DCFD1E6D" "$B/FVMAIN.Fv.txt" 2>/dev/null | head -3
echo "=== .Fv.txt line count ==="
wc -l "$B/FVMAIN.Fv.txt" 2>/dev/null
echo "=== any SimpleFb in FVMAIN.Fv.txt ==="
grep -ic "simplefb" "$B/FVMAIN.Fv.txt" 2>/dev/null