set +e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "== entries count =="; grep -c '^  {"' "$F"
echo "== usb/dwc3 related lines =="; grep -n -i 'usb\|dwc3\|0A600000\|088E' "$F" | head -20
echo "== last 6 entries =="; grep -n '^  {"' "$F" | tail -6
echo "== restore backups present? =="; ls -la /tmp/MemoryMapLib.c.bak* 2>/dev/null | tail -5