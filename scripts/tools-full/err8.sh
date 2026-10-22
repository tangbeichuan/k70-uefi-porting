set +e
L=/root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt
grep -n "error:\|Error:" "$L" | tail -8