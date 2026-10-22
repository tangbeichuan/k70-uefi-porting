set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
grep -n "SimpleTextIn instances\|LocateHandleBuffer\|Handles\[\|ReadKeyStroke\|mInstances" "$F" | head -20