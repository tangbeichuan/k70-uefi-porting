set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
wc -l "$F"
grep -n 'last key\|GuiText (\|Redraw\|STATUS' "$F" | head -30