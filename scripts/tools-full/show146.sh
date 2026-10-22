set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
ls -1 run_keys14*.sh build_keys14*.sh 2>/dev/null | tail -20
echo "=== run_keys146.sh ==="
cat run_keys146.sh 2>/dev/null
echo "=== build_keys146.sh (first 60 lines) ==="
sed -n '1,60p' build_keys146.sh 2>/dev/null
echo "=== tail of build_keys146.sh ==="
tail -30 build_keys146.sh 2>/dev/null