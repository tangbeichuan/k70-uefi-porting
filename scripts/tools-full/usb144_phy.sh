#!/bin/bash
set -e
dtc -I dtb -O dts /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb -o /tmp/xbl_ufs.dts 2>/dev/null
echo "=== DTS: usb0 / hs_phy_cfg / ss_phy_cfg ==="
grep -n 'usb0 {\|hs_phy_cfg\|ss_phy_cfg' /tmp/xbl_ufs.dts | head
echo
python3 - <<'PY'
import re
src=open('/tmp/xbl_ufs.dts').read().split('\n')
# print the usb0 node block
for i,L in enumerate(src):
    if re.search(r'\busb0\s*\{', L):
        base=len(L)-len(L.lstrip('\t'))
        print('\n'.join(src[i:i+120]))
        break
PY
echo
echo "=== UsbfnDwc3Dxe strings around phy cfg / property names ==="
strings -t x /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi | grep -iE 'phy|tune|override|usb|qcom|drive|squelch|boost' | head -60
echo
echo "=== UsbDeviceDxe strings ==="
strings -t x /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbDeviceDxe/UsbDeviceDxe.efi | grep -iE 'phy|tune|override|usb|qcom|drive|squelch|boost' | head -40
