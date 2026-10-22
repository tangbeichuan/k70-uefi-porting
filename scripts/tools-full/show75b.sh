set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
sed -n '395,540p' "$F"
echo "==== TAIL 620-680 ===="
sed -n '620,690p' "$F"