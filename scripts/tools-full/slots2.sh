set +e
H=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi
P=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxeLa/PmicDxeLa.efi
ls -l "$H" "$P"
llvm-objdump -d --no-show-raw-insn "$H" > /tmp/halio.asm 2>/dev/null
llvm-objdump -d --no-show-raw-insn "$P" > /tmp/pmic.asm 2>/dev/null
wc -l /tmp/halio.asm /tmp/pmic.asm
echo "=== HALIOMMU: ldr ..#0x40] ==="
grep -nE 'ldr\s+x[0-9]+, \[x[0-9]+, #0x40\]' /tmp/halio.asm | head
echo "=== PMIC: slots 0x40 / 0x88 / 0x90 / 0xa0 / 0xa8 ==="
grep -nE 'ldr\s+x[0-9]+, \[x[0-9]+, #0x(40|88|90|98|a0|a8)\]' /tmp/pmic.asm | head -20