set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -n 'define.*TAG' "$F" | head
echo "--- GetProp head ---"
grep -n 'EfiApi_GetProp' -A25 "$F" | head -45