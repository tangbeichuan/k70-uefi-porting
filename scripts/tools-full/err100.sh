set +e
grep -n "error:" /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | tail -8
echo '---'
grep -n "VermeerKeyProbeDxe.c" /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | tail -6