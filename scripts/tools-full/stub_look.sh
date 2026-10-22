set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -n 'EfiApi_Unsupported' -A6 -B2 "$F" | head -40
echo "=== interface slot fill ==="
grep -n '0x100\]' -B4 -A8 "$F" | head -40