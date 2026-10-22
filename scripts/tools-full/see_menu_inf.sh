set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
I=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.inf
echo "=== menu INF ==="
cat "$I"
echo "=== includes ==="
grep -n "^#include" "$F" | head -12