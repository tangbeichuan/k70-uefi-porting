set +e
A=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== lines 185-215 ==="
sed -n '185,215p' "$A" | cat -n
echo "=== all !if / !else / !endif ==="
grep -n "^!if\|^!else\|^!endif" "$A"
echo "=== our SimpleFb line context ==="
grep -n -B3 -A3 "SimpleFbDxe" "$A"