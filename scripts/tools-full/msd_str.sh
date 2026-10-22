set +e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbMsdDxe/UsbMsdDxe.efi
ls -l "$F"
echo "=== strings of interest ==="
strings -a "$F" | grep -i -E 'lun|partition|blockio|UsbFnIo|disk|msd' | head -40