set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
ls -l "$F"
sed -n '/EfiApi_Unsupported (/,/^}/p' "$F"