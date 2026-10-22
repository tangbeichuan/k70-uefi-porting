set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/^trap restore EXIT/#norestore/' run_keys69.sh > /tmp/run69n.sh
bash /tmp/run69n.sh keys69n > /tmp/k69n.log 2>&1
echo "exit=$?"
grep -nE 'kept vendor|dropped lines|UFSDxe kept|Success|error' /tmp/k69n.log | tail -6
echo "=== APRIORI.inc 里 halio 行（应该有 # [keys47-drop] 前缀）==="
grep -n -i 'halio' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== FVMAIN 里 9A00771F 计数 ==="
grep -c '9A00771F' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
echo "=== FVMAIN 条目数 ==="
grep -c '^0x' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt