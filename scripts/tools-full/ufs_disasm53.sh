set +e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi
[ -f "$F" ] || F=$(find /root/k70/uefi -name 'UFSDxe*.efi' | head -1)
echo "file=$F"
echo "=== around 0x17CC (caller) ==="
llvm-objdump -d --start-address=0x1700 --stop-address=0x1810 "$F" 2>/dev/null | sed -n '1,200p'
echo "=== around 0x9E3C ==="
llvm-objdump -d --start-address=0x9DF0 --stop-address=0x9E80 "$F" 2>/dev/null | sed -n '1,120p'
