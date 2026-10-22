set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "UFS71\|UFS74\|UFS75\|UFS79\|0x58\|0x60\|0x50\|0x54\|utrd\|UTR" "$F" | head -40
echo "--- total lines ---"; wc -l "$F"