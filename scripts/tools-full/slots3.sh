set +e
sed -n '3905,3945p' /tmp/halio.asm
echo "===== ??? ====="
sed -n '7619,7659p' /tmp/halio.asm
echo "===== PMIC ?? ====="
find /root/k70/uefi/Binaries -iname 'PmicDxeLa.efi' | head