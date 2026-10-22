#!/bin/bash
set -e
for M in UsbfnDwc3Dxe UsbDeviceDxe; do
  echo "================ $M strings (DTB/props/physics) ================"
  strings -t x /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/$M/$M.efi | grep -iE 'phy|tune|table|soc/usb|qcom|hs_|ss_|cfg|prop|node|override|drive|squelch|boost|iommu|smmu' | head -50
  echo
done
