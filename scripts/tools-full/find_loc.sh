set +e
cd /root/k70/uefi
grep -rn "LocateMemoryRegionByName" --include="*.c" --include="*.h" Silicon Platforms | head -8