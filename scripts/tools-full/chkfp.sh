set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
sed -n '/^FdtGetProp (/,/^}/p' "$F" | tail -20