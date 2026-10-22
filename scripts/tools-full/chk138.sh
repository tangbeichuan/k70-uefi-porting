set +e
cd /root/k70/uefi/Platforms/Xiaomi/vermeerPkg
grep -rn -i "pmic" Include/APRIORI.inc Include/DXE.inc Include/RAW.inc 2>/dev/null | head -20
echo "--- log tail of dropped ---"
grep -n "dropped:" /tmp/b138.log | head -5