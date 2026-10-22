set +e
L=/root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt
grep -n "GenFv: ERROR\|same file GUID\|F002\|error 7000\|No rule" "$L" | tail -5
echo "--- counts after run ---"
for f in Include/APRIORI.inc vermeer.fdf vermeer.dsc; do
  printf "%-22s %s\n" "$f" "$(grep -c 'SimpleFbDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/$f 2>/dev/null)"
done
echo "--- where in fdf ---"
grep -n -B2 -A2 "SimpleFbDxe" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf 2>/dev/null | head -12