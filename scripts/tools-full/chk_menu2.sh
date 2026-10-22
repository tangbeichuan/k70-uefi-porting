set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
grep -n "Vermeer UEFI menu\|Say (L\"  ====\|DeviceInfor\|idle 3 s" "$F" | head -12