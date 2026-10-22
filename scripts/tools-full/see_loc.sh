set +e
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
grep -n "LocateMemoryRegionByName" -A 40 "$M" | head -55