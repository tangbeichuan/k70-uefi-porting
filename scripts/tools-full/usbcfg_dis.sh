set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.efi
llvm-objdump -d "$D" > /tmp/usbcfg.asm 2>/dev/null
grep -n 'add.*#0x476' /tmp/usbcfg.asm | head -5
echo "=== context ==="
LN=$(grep -n 'add.*#0x476' /tmp/usbcfg.asm | head -1 | cut -d: -f1)
if [ -n "$LN" ]; then sed -n "$((LN-25)),$((LN+15))p" /tmp/usbcfg.asm; fi