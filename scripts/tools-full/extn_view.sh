set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -n 'MaxSize\|size=64\|64)\|SlotGetGeneric' "$F" | head -30