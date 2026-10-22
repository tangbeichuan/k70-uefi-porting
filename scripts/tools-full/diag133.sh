set +e
echo "=== log head ==="
head -30 /tmp/b133.log
echo "=== does FV use Binaries copy? ==="
grep -rn 'VermeerDtbExtnDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/*.inc 2>/dev/null | head
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/VermeerDtbExtnDxe/ 2>/dev/null | cat