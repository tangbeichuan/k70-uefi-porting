set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "mHeader\|UfsDirectTest" "$F" | head -10
echo '--- context ---'
sed -n '880,905p' "$F"