set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
grep -n "STATIC.*ConOut\|Say (\|VOID\s*Say\|ConOut (" "$F" | head -10