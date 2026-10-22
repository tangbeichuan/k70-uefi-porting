set +e
grep -E "VermeerDtbExtnDxe.c:[0-9]+:[0-9]+: error" /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | head -5
echo "=== mVars 定义区 ==="
grep -n "mInstalled" /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c | head