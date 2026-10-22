set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -nE 'STATIC .*mCallCount' "$F"
python3 /mnt/d/本地项目-01/_tools/patch_extn58.py || exit 1
echo "=== build keys58 ==="
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys58 2>&1 | tail -8