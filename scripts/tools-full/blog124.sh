set +e
grep -n 'error:\|ERROR 20\|GenFv' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | tail -15