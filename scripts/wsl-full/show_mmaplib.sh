set -u
cd /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib
echo "=== head (1..30) ==="
sed -n '1,30p' MemoryMapLib.c
echo
echo "=== lines 30..60 ==="
sed -n '30,60p' MemoryMapLib.c
echo
echo "=== tail ==="
tail -12 MemoryMapLib.c
