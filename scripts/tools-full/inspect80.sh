set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
grep -n "build_uefi\|APRIORI\|vermeer.fdf\|EXTN\|FREEF" run_keys80.sh | head -30
echo "=== tail 25 ==="
tail -25 run_keys80.sh