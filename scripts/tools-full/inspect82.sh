set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "=== run_keys82.sh (head 60) ==="
sed -n '1,60p' run_keys82.sh
echo "=== grep patch/pei ==="
grep -nE "patch|PlatformPei|CompareGuid|scheduler|XblProtocols" run_keys82.sh run_keys67.sh 2>/dev/null | head -20