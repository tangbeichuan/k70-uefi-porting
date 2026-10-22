set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "0x50\|0x54\|0x58\|0x60\|0x3c\|own descriptors" "$F" | head -40