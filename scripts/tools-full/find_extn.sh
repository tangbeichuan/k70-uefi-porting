set +e
find /root/k70/uefi/Build -name 'VermeerDtbExtnDxe.*' -newermt '2026-10-22 00:20' 2>/dev/null | head
echo "--- any ---"
find /root/k70/uefi/Build -name 'VermeerDtbExtnDxe.efi' 2>/dev/null | head
grep -c 'A3, 512)' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c