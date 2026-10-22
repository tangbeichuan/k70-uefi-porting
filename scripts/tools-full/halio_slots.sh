set +e
U=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
H=$U/HALIOMMU/HALIOMMU.efi
ls -l "$H" 2>/dev/null || find /root/k70/uefi/Binaries -name 'HALIOMMU*.efi' | head
llvm-objdump -d "$H" 2>/dev/null > /tmp/halio.asm
wc -l /tmp/halio.asm
echo "=== ? ldr xN,[xM,#0x40] ?? blr ???? ==="
grep -n 'ldr	x[0-9]*, \[x[0-9]*, #0x40\]' /tmp/halio.asm | head -20
echo "=== ? 0x98/0xa0/0x88 ? ==="
grep -nE 'ldr	x[0-9]*, \[x[0-9]*, #0x(88|90|98|a0|a8)\]' /tmp/halio.asm | head -20