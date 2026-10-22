set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
ls -l "$F" 2>/dev/null || echo "NO port-driver copy"
for pat in GuiMenu LocateHandleBuffer MENU105 MENU102 ReadKeyStroke; do
  printf "%-20s %s\n" "$pat" "$(grep -c "$pat" "$F" 2>/dev/null)"
done
echo "--- tools copies ---"
ls -l /mnt/d/本地项目-01/_tools/VermeerMenuDxe* 2>/dev/null | head