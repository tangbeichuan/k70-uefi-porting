#!/usr/bin/env bash
# k157_probe3.sh -- refresh pkg copies and verify the early USB157 block lands
set -e
TOOLS=/mnt/d/本地项目-01/_tools
python3 "$TOOLS/patch_copy123.py"
python3 "$TOOLS/patch_extn136.py"
D=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
echo "--- pkg DtbExtn: $D ($(stat -c%s "$D") B) ---"
grep -nE 'USB157|early pre|early run|early bring-up' "$D" | head -12
echo "--- src DtbExtn ---"
S=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
echo "src size $(stat -c%s "$S")  pkg size $(stat -c%s "$D")"
sha256sum "$S" "$D"
echo "--- MemoryMapLib GCC row? ---"
grep -n 'GCC' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c || echo "  none (expected)"
echo "--- APRIORI first entries ---"
grep -nE 'VermeerDtbExtnDxe|HALIOMMUDxe|UsbConfigDxe|UsbInitDxe|UsbMsdDxe|VermeerMenuDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc | head -12
