set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "UFS79\|UFS75\|UFS74_DUMPONLY\|// UFS" "$F" | sed -n '1,40p'