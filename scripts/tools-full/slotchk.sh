set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "SetIfcSlot\|EfiApi_SlotA0\|EfiApi_Slot20\|slot 0x%03x called" "$F" | head -30