set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
sed -n '78,120p' "$F"
echo "=== count GuiRect defs ==="
grep -n "^GuiRect (\|^GuiText (\|^GuiStatusPage (\|^GuiMenu (" "$F"