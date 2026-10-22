#!/bin/bash
set -u
DTB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
OUT=/mnt/d/本地项目-01/_tools/k148_xbl_ufs.dts
mkdir -p "$(dirname "$OUT")"
dtc -I dtb -O dts -o "$OUT" "$DTB" 2>/dev/null || { echo DTC_FAIL; exit 1; }
echo "DTS=$OUT lines=$(wc -l < "$OUT")"
echo '===== usb0 node ====='
awk '/^\t\tusb0@/{f=1} f{print} f&&/^\t\t};/{exit}' "$OUT" | head -80
echo '===== usb-related phy nodes ====='
grep -n -E 'qcom,usb|snps,dwc3|qusb|usb2-phy|usb-ssphy|combo-phy|hs_phy_cfg|ss_phy_cfg|usb_shared|dwc3@' "$OUT" | head -60