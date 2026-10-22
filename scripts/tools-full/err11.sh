set +e
L=/root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt
grep -n "error:" "$L" | tail -5