set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
echo "=== 0x30 ==="
sed -n '/EfiApi_GetNode (/,/^}/p' "$F"
echo "=== 0x58 ==="
sed -n '/EfiApi_GetProp (/,/^}/p' "$F"
echo "=== 0xa8 ==="
sed -n '/EfiApi_GetPropByte (/,/^}/p' "$F"