set +e
cd /root/k70/uefi
grep -rn "LocateMemoryRegionByName" --include="*.c" . 2>/dev/null | grep -v "Status = Locate\|= LocateMemoryRegionByName" | head -8
echo "--- library dirs named MemoryMap* ---"
find . -path ./Build -prune -o -type d -name "MemoryMap*" -print 2>/dev/null | head -10