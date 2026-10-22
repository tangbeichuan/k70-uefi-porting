set +e
cd /root/k70/uefi
grep -rn "LocateMemoryRegionByName" --include="*.c" Silicon/Qualcomm Silicon/Silicium 2>/dev/null | grep -i "EFI_STATUS\|^.*:.*VOID" | head -5
echo "--- definition search in MemoryMapLib ---"
grep -rn "LocateMemoryRegionByName" Silicon/Qualcomm/QcomPkg/Library/MemoryMapLib/*.c Silicon/Qualcomm/QcomPkg/Include/Library/*.h 2>/dev/null | head -5
echo "--- vermeer MemoryMapLib ---"
grep -n "LocateMemoryRegionByName" Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c | head -3