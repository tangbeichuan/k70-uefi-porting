set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi
ls -l "$D" | cat
llvm-objdump -d "$D" > /tmp/pmic.asm 2>/dev/null
wc -l /tmp/pmic.asm
sed -n "/1e360:/,/1e3d0:/p" /tmp/pmic.asm | head -40