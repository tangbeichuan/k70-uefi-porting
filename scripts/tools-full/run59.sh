set +e
python3 /mnt/d/本地项目-01/_tools/patch_extn59.py || exit 1
echo "=== build keys59 ==="
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys59 2>&1 | tail -12