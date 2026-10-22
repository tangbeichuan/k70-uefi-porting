set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash run_keys69.sh keys69 > /tmp/k69.log 2>&1
echo "exit=$?"
grep -nE "error|ERROR|Error|failed|FAILED" /tmp/k69.log | head -20
tail -25 /tmp/k69.log
echo "=== FD 时间 ==="
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd