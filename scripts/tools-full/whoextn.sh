set +e
grep -ln 'VermeerDtbExtnDxe' /mnt/d/本地项目-01/_tools/*.py 2>/dev/null
echo "=== which are called by build_keys135 ==="
grep -n 'python3 /mnt/d/本地项目-01/_tools' /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys135.sh