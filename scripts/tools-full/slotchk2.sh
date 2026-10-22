set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
echo "== lines: $(wc -l < $F)"
grep -n "mIfc\|Ifc\[\|0x108\|Version\|GetProp\|GetNode" "$F" | head -40