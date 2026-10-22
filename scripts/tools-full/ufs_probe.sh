#!/usr/bin/env bash
# What is UFSDxe looking for?  The assert is "Status = Not Found" ->
# "ASSERT [UFS.coreDxeLib.c +163]: !EFI_ERROR (eResult)".  Dump the strings of the prebuilt
# UFSDxe.efi and look for variable names / DT properties / protocol names it may fail to find.
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
EFI=$(find "$B" -iname 'UFSDxe.efi' | head -1)
echo "=== $EFI"; ls -l "$EFI"
echo
echo "--- UTF-16LE strings mentioning ufs/vcc/gear/hs-/pwr/clk (variable + DT names) ---"
strings -el "$EFI" | grep -iE 'ufs|vcc|vccq|gear|hs-|pwr|clk|freq|supply|iommu|descriptor|bRefClk|LUN|boot_lun' | sort -u | head -60
echo
echo "--- ASCII strings mentioning .c: (assert sites) ---"
strings -a "$EFI" | grep -E '\.c$|\.c\b' | sort -u | head -30
echo
echo "--- does it reference other drivers' protocols by name? ---"
strings -el "$EFI" | grep -iE 'Protocol|guid' | sort -u | head -40
