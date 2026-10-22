set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash build_keys133.sh keys133 > /tmp/b133b.log 2>&1
echo "exit=$?"
echo "=== lines: $(wc -l < /tmp/b133b.log) ==="
grep -nE 'error|Error|ERROR|warning: |Build|build_uefi|GenFv' /tmp/b133b.log | head -20
tail -15 /tmp/b133b.log