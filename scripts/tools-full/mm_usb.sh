set +e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "=== USB / 0xA6 / 0x88E entries ==="
grep -n -i 'usb\|0x0A6\|0x0a6\|0x088E\|0x088e' "$F" | head -20
echo "=== all entries containing 0x08 or 0x0A prefix ==="
grep -n '{"' "$F" | sed -n '1,60p'