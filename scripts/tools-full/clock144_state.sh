#!/bin/bash
set +e
W=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== DXE.inc: ClockDxe line (pristine) ==="
grep -n -i 'ClockDxe' $W/Include/DXE.inc
echo
echo "=== APRIORI.inc: ClockDxe line + UsbConfigDxe context (pristine) ==="
grep -n -i 'ClockDxe' $W/Include/APRIORI.inc
grep -n -i 'UsbConfigDxe\|VermeerPmicVerStubDxe\|UsbInitDxe\|UsbMsdDxe\|HALIOMMUDxe' $W/Include/APRIORI.inc
echo
echo "=== build_keys143b.sh: patch chain + NO_HAL + sed/tag lines ==="
grep -n 'NO_HAL\|patch_\|TAG=\|keys143b' /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys143b.sh | head -30
echo
echo "=== run_keys143b.sh ==="
cat /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys143b.sh
