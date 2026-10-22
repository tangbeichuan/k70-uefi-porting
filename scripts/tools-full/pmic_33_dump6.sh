#!/bin/bash
set -e
D=/mnt/d/本地项目-01/_tools
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi
mkdir -p /tmp/pmic
if [ ! -s /tmp/pmic/pmic.asm ]; then llvm-objdump -d "$EFI" > /tmp/pmic/pmic.asm; fi
python3 "$D/pmic_an.py" show 1f490 1f540
echo "==== 1f940-1fac0"
python3 "$D/pmic_an.py" show 1f940 1fac0
echo "==== 1e320-1e420"
python3 "$D/pmic_an.py" show 1e320 1e420
