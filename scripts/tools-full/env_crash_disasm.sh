#!/bin/bash
set -e
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi
cp "$E" /tmp/EnvDxe.efi
cd /tmp
echo "=== PE sections (file offset == RVA?) ==="
aarch64-linux-gnu-objdump -h EnvDxe.efi | sed -n '1,20p'
echo
echo "=== crash PC 0x6088 context (0x6000..0x6120) ==="
aarch64-linux-gnu-objdump -d --start-address=0x6000 --stop-address=0x6120 EnvDxe.efi | sed -n '1,80p'
echo
echo "=== install path 0x2b80..0x2c40 ==="
aarch64-linux-gnu-objdump -d --start-address=0x2b80 --stop-address=0x2c40 EnvDxe.efi | sed -n '1,80p'
