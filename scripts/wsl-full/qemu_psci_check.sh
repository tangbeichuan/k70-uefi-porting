set -uo pipefail
# Confirm the diagnosis of the QEMU exception: the firmware's reset path issues an SMC
# (Qualcomm's PSCI conduit is smc), but `-M virt` defaults to hvc, so the SMC is undefined
# and surfaces as a "Synchronous Exception" with ESR EC=0.  Two ways to show it:
#   (a) boot with psci-conduit=smc and see the run end cleanly instead of crashing;
#   (b) disassemble ResetSystemRuntimeDxe around the reported PC.
WORK=/root/k70/qemu-serial
FB_OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
cd "$WORK"

echo "=== (a) same firmware, psci-conduit=smc ==="
rm -f serial-smc.log
timeout 30 qemu-system-aarch64 \
  -M virt,psci-conduit=smc,gic-version=3 -cpu max -m 3072 -smp 8 \
  -display none -monitor none -serial "file:$WORK/serial-smc.log" \
  -kernel "$WORK/composite.bin" >/dev/null 2>&1
echo "qemu exit: $?"
echo "--- last 12 lines ---"
sed 's/\r$//' "$WORK/serial-smc.log" | tail -12
echo
echo "=== exception check ==="
if grep -q "Synchronous Exception" "$WORK/serial-smc.log"; then
  echo "STILL CRASHES with psci-conduit=smc"
else
  echo "no synchronous exception with psci-conduit=smc"
fi
cp -f "$WORK/serial-smc.log" "$FB_OUT/qemu-serial-psci-smc.log"

echo
echo "=== (b) copy ResetSystemRuntimeDxe.efi out for disassembly ==="
MOD=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/MdeModulePkg/Universal/ResetSystemRuntimeDxe/ResetSystemRuntimeDxe/DEBUG/ResetSystemRuntimeDxe.efi
ls -l "$MOD"
cp -f "$MOD" "$FB_OUT/ResetSystemRuntimeDxe.efi"
echo "exception PC offset inside the module: 0x10038 (module base 0xC71D0000, PC 0xC71E0038)"
