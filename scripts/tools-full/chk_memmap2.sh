set +e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
grep -n "UFS\|1D80000\|1d80000\|NOMAP\|XBL DT" "$F" | head -20
echo "--- lines ---"; wc -l "$F"