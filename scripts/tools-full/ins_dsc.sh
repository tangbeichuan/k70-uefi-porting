set +e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo "=== sections ==="; grep -n '^\[' "$F"
echo "=== Components area (first 40 lines after [Components]) ==="
awk '/^\[Components/{f=1} f{print NR": "$0; c++} c>40{exit}' "$F"
echo "=== does dsc contain VermeerMenuDxe? ==="; grep -n 'VermeerMenuDxe' "$F" || echo none