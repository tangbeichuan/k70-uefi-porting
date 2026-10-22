#!/bin/bash
set -e
B=/root/k70/uefi/_k70port_extract/wsl
ls -l /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys141.sh 2>/dev/null || true
echo "=== patch chain lines (build_keys141.sh) ==="
grep -n "patch_\|build_uefi.py\|restore\|RESTORE\|trap" /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys141.sh | head -40
echo "=== tail 20 ==="
tail -20 /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys141.sh
echo "=== AcpiTableDxe INF depex ==="
grep -n -A3 "\[Depex\]" /root/k70/uefi/Mu_Basecore/MdeModulePkg/Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf | head -10
