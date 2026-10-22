set +e
P=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "APRIORI:"; grep -n 'LogDisk' "$P/Include/APRIORI.inc"
echo "DXE.inc:"; grep -n 'LogDisk' "$P/Include/DXE.inc"
echo "fdf:"; grep -n 'LogDisk' "$P/vermeer.fdf"