set +e
grep -E "error|Error|警告|warning" /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt | grep -i "verm" | head -20
echo "=== 直接编译错误上下文 ==="
ls /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe*/OUTPUT/ 2>/dev/null | head