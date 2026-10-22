#!/usr/bin/env bash
# k166_scan.sh -- DT facts for DWC3 SID + SMMU base; local SMMU register references.
set -e
DTB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
DTS=/tmp/k166.dts
dtc -I dtb -O dts "$DTB" > "$DTS" 2>/dev/null
echo "===== usb nodes ====="
grep -nE "usb@|usb0|qcom,usb|dwc3" "$DTS" | head -40 || true
echo
echo "===== iommus entries (all) ====="
grep -n "iommus" "$DTS" | head -40 || true
echo
echo "===== apps_smmu node ====="
awk '/apps_smmu|smmu/{p=1} p{print NR": "$0; c++} c>60{exit}' "$DTS" | head -80 || true
echo
echo "===== usb0 context (iommus/phys) ====="
awk 'NR>=1560 && NR<=1700' "$DTS" | grep -nE "usb|iommus|reg =|compatible" | head -30 || true
echo
echo "===== repo refs to S2CR/SMR/apps_smmu ====="
grep -rIl --include=*.h --include=*.c --include=*.dsc --include=*.inc -E "S2CR|SMMU_SMR|apps_smmu|ARM_SMMU" /root/k70/uefi/Silicon /root/k70/uefi/Mu_Basecore 2>/dev/null | head -20 || true
echo
echo "===== MemoryMapLib region rows (current) ====="
grep -nE '^\s*\{\s*"' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c | head -50 || true
