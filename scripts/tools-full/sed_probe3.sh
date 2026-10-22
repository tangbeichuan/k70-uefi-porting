set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c
grep -n "UfsWr (0x60\|UfsWr (0x50\|UfsWr (0x54\|OldLo\|OldHi\|OldRun\|own descriptors\|TUR" "$F" | head -20
echo "=== 725..800 ==="
sed -n '725,800p' "$F"