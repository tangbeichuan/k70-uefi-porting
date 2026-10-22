set +e
D=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
grep -n "USE_CUSTOM_DISPLAY_DRIVER" "$D"
echo "--- APRIORI display block ---"
sed -n '108,125p' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc