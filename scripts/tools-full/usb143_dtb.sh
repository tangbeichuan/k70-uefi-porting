#!/bin/bash
set -e
DTB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
dtc -I dtb -O dts $DTB > /tmp/xbl_ufs.dts 2>/dev/null
echo "=== iommu/smmu/iort nodes ==="
grep -n -iE "iommu|smmu|iort" /tmp/xbl_ufs.dts | head -30
echo "=== /soc top-level children ==="
python3 - <<'PY'
import re
txt=open('/tmp/xbl_ufs.dts').read()
# print top-level node names
depth=0; names=[]
for line in txt.splitlines():
    s=line.strip()
    if s.endswith('{'): depth+=1
    elif s.startswith('}'): depth-=1
    if depth==2 and s.endswith('{') and not s.startswith('&'):
        names.append(s.split('{')[0].strip().rstrip('{').strip())
print(names[:80])
PY
echo "=== usb nodes ==="
grep -n -E "usb[0-9]?@|usb_[0-9]|qcom,usb|usb-phy" /tmp/xbl_ufs.dts | head -20
echo "=== HALIOMMU DTBExtn-related strings (all printable 6+) ==="
strings -n 6 /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi | grep -vE "^/home|^/root|\.c$|\.h$" | head -60
