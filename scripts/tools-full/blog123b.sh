set +e
grep -n 'GenFv\|ERROR\|error 7000' /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | tail -12