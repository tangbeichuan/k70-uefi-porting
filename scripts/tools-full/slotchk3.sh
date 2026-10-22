set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
echo "== lines: $(wc -l < $F)"
grep -n "SetIfcSlot\|EfiApi_Slot\|mStubTable\|0xa8\|0xa0\|0x98" "$F" | head -40