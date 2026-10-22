set +e
grep -E "VermeerDtbExtnDxe.c:[0-9]+:[0-9]+: (error|warning)" /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | head -6