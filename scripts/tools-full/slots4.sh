set +e
echo "===== HALIOMMU ?? #0x40] ?? 6 ? ====="
awk '/#0x40\]/{print NR": "$0; for(i=1;i<=6;i++){getline; print "     "$0}}' /tmp/halio.asm | head -60
echo
echo "===== PMIC ??? ====="
P=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi
llvm-objdump -d --no-show-raw-insn "$P" > /tmp/pmic.asm 2>/dev/null
wc -l /tmp/pmic.asm
for off in 88 90 a0 a8; do
  echo "--- slot 0x$off ---"
  awk -v pat="#0x$off]" '$0 ~ pat {print NR": "$0; for(i=1;i<=6;i++){getline; print "     "$0}}' /tmp/pmic.asm | head -24
done