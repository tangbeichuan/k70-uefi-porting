set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "ReadKeyStroke\|VOL-UP / VOL-DOWN to move\|while (TRUE)\|for (;;)\|CpuDeadLoop" "$F" | head -20
echo '--- entry tail ---'
sed -n '905,960p' "$F"