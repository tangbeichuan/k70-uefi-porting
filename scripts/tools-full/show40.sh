set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
echo "=== FdtGetProp 定义 ==="
sed -n '/^FdtGetProp (/,/^}/p' "$F"
echo "=== GetProp 实现的槽位 ==="
grep -n "FdtGetProp (" "$F" | head
echo "=== Slot40 现状 ==="
sed -n '/EfiApi_Slot40 (/,/^}/p' "$F"